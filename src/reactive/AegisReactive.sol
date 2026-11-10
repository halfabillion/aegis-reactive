// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";
import { AegisMath } from "../AegisMath.sol";

/// @title AegisReactive
/// @notice Reactive contract. Subscribes to origin logs, keeps the position and the posted
///         policy, and requests a destination callback only when both say to act.
/// @dev Inherits AbstractReactive from reactive-lib-omni. SYSTEM is the real Omni system
///      contract address baked into that library. react() is onlySystem.
contract AegisReactive is AbstractReactive {
    uint64 public constant CALLBACK_GAS_LIMIT = 1_000_000;

    error NotOwner(address caller);
    error ZeroAddress();
    error VaultAlreadySet();

    event VaultSet(address indexed vault);
    event PositionRegistered(uint256 indexed feedId, uint256 entryPrice, uint256 size);
    event PolicyAccepted(
        uint256 indexed feedId,
        uint64 epoch,
        uint16 stopBps,
        uint8 action,
        uint16 confidenceBps,
        bytes32 featuresHash
    );
    event PolicyRejected(uint256 indexed feedId, uint64 epoch, uint16 confidenceBps);
    event PriceObserved(uint256 indexed feedId, uint256 price, uint256 drawdownBps);
    event ProtectionRequested(
        uint256 indexed feedId, uint256 price, uint8 action, uint256 drawdownBps, uint256 requiredBps
    );

    struct Feed {
        uint256 entryPrice;
        uint256 size;
        uint256 lastPrice;
        bool open;
        bool stopSent;
        bool pauseSent;
        bool policySet;
        uint64 epoch;
        uint16 stopBps;
        uint8 action;
        uint16 confidenceBps;
        bytes32 featuresHash;
    }

    uint256 public immutable originChainId;
    uint256 public immutable destinationChainId;
    address public immutable origin;
    uint256 public immutable positionTopic0;
    uint256 public immutable priceTopic0;
    uint256 public immutable policyTopic0;

    address public owner;
    address public vault;
    mapping(uint256 feedId => Feed) public feeds;

    constructor(uint256 originChainId_, uint256 destinationChainId_, address origin_) payable {
        if (origin_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        originChainId = originChainId_;
        destinationChainId = destinationChainId_;
        origin = origin_;
        positionTopic0 = uint256(keccak256("PositionOpened(uint256,uint256,uint256)"));
        priceTopic0 = uint256(keccak256("PriceUpdated(uint256,uint256,uint64)"));
        policyTopic0 = uint256(keccak256("PolicyPosted(uint256,uint64,uint16,uint8,uint16,bytes32)"));

        SYSTEM.subscribe(originChainId_, origin_, positionTopic0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        SYSTEM.subscribe(originChainId_, origin_, priceTopic0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
        SYSTEM.subscribe(originChainId_, origin_, policyTopic0, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    function setVault(address vault_) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (vault_ == address(0)) revert ZeroAddress();
        if (vault != address(0)) revert VaultAlreadySet();
        vault = vault_;
        emit VaultSet(vault_);
    }

    /// @notice Settles a debt balance against this contract's REACT. No-op when debt is zero.
    function coverDebt() external {
        _coverDebt();
    }

    function bounds() external pure returns (uint16 minConfidenceBps, uint16 minStopBps, uint16 maxStopBps) {
        return (AegisMath.MIN_CONFIDENCE_BPS, AegisMath.MIN_STOP_BPS, AegisMath.MAX_STOP_BPS);
    }

    function evaluate(uint256 feedId, uint256 price)
        external
        view
        returns (bool fire, uint8 action, uint256 drawdown, uint256 required)
    {
        Feed storage feed = feeds[feedId];
        action = feed.action;
        (fire, drawdown, required) = _shouldFire(feed, price);
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external override onlySystem {
        if (log_.chainId != originChainId || log_.contractAddress != origin || log_.opCode != 2) return;
        if (log_.topic0 == positionTopic0) {
            _onPosition(log_);
        } else if (log_.topic0 == policyTopic0) {
            _onPolicy(log_);
        } else if (log_.topic0 == priceTopic0) {
            _onPrice(log_);
        }
    }

    function _onPosition(LogRecord calldata log_) internal {
        uint256 feedId = log_.topic1;
        (uint256 entryPrice, uint256 size) = abi.decode(log_.data, (uint256, uint256));
        if (entryPrice == 0 || size == 0) return;
        Feed storage feed = feeds[feedId];
        feed.entryPrice = entryPrice;
        feed.size = size;
        feed.lastPrice = entryPrice;
        feed.open = true;
        feed.stopSent = false;
        feed.pauseSent = false;
        emit PositionRegistered(feedId, entryPrice, size);
        if (feed.policySet && vault != address(0)) _requestSync(feedId, feed);
    }

    function _onPolicy(LogRecord calldata log_) internal {
        uint256 feedId = log_.topic1;
        (uint64 epoch, uint16 stopBps, uint8 action, uint16 confidenceBps, bytes32 featuresHash) =
            abi.decode(log_.data, (uint64, uint16, uint8, uint16, bytes32));
        Feed storage feed = feeds[feedId];
        if (
            confidenceBps < AegisMath.MIN_CONFIDENCE_BPS || action > AegisMath.PAUSE || epoch == 0
                || epoch <= feed.epoch
        ) {
            emit PolicyRejected(feedId, epoch, confidenceBps);
            return;
        }
        uint16 clamped = AegisMath.clampStop(stopBps);
        feed.epoch = epoch;
        feed.stopBps = clamped;
        feed.action = action;
        feed.confidenceBps = confidenceBps;
        feed.featuresHash = featuresHash;
        feed.policySet = true;
        feed.pauseSent = false;
        emit PolicyAccepted(feedId, epoch, clamped, action, confidenceBps, featuresHash);
        if (feed.open && vault != address(0)) _requestSync(feedId, feed);
    }

    function _onPrice(LogRecord calldata log_) internal {
        uint256 feedId = log_.topic1;
        (uint256 price, uint64 updatedAt) = abi.decode(log_.data, (uint256, uint64));
        if (price == 0) return;
        Feed storage feed = feeds[feedId];
        feed.lastPrice = price;
        (bool fire, uint256 drawdown, uint256 required) = _shouldFire(feed, price);
        emit PriceObserved(feedId, price, drawdown);
        if (!fire) return;
        _request(
            abi.encodeWithSignature(
                "protect(address,uint256,uint256,uint64,uint64,uint8)",
                address(0),
                feedId,
                price,
                updatedAt,
                feed.epoch,
                feed.action
            )
        );
        if (feed.action == AegisMath.PAUSE) feed.pauseSent = true;
        else feed.stopSent = true;
        emit ProtectionRequested(feedId, price, feed.action, drawdown, required);
    }

    function _shouldFire(Feed storage feed, uint256 price)
        internal
        view
        returns (bool fire, uint256 drawdown, uint256 required)
    {
        drawdown = AegisMath.drawdownBps(feed.entryPrice, price);
        required = AegisMath.triggerBps(feed.stopBps, feed.action);
        fire = feed.open && feed.policySet && !feed.stopSent && vault != address(0) && feed.action != AegisMath.HOLD
            && drawdown >= required && !(feed.action == AegisMath.PAUSE && feed.pauseSent);
    }

    function _requestSync(uint256 feedId, Feed storage feed) internal {
        _request(
            abi.encodeWithSignature(
                "syncPolicy(address,uint256,uint64,uint16,uint8,uint16,bytes32)",
                address(0),
                feedId,
                feed.epoch,
                feed.stopBps,
                feed.action,
                feed.confidenceBps,
                feed.featuresHash
            )
        );
    }

    function _request(bytes memory payload) internal {
        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: destinationChainId,
                recipient: vault,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }
}
