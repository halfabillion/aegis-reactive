// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";
import { AegisMath } from "../AegisMath.sol";

/// @title AegisVault
/// @notice Destination callback contract. It re-checks the posted policy against its own entry
///         price before pausing or closing a mock position.
/// @dev Deploy with the chain's callback proxy and the reactive contract address. The first
///      argument of every callback is the reactive sender injected by the network.
contract AegisVault is AbstractCallback {
    error NotOwner(address caller);
    error ZeroValue();
    error AlreadyOpen();
    error FeedNotOpen();
    error PolicyNotSet();
    error EpochMismatch(uint64 got, uint64 expected);
    error ActionMismatch(uint8 got, uint8 expected);
    error HoldDoesNotProtect();
    error StopOutOfRange(uint16 stopBps);
    error ConfidenceTooLow(uint16 confidenceBps);
    error BadAction(uint8 action);
    error FuturePrice(uint64 updatedAt);
    error StalePrice(uint64 updatedAt, uint64 nowTs);
    error ConditionsNotMet(uint256 drawdownBps, uint256 requiredBps);

    event PositionOpened(uint256 indexed feedId, uint256 entryPrice, uint256 size);
    event PolicySynced(
        uint256 indexed feedId, uint64 epoch, uint16 stopBps, uint8 action, uint16 confidenceBps, bytes32 featuresHash
    );
    event Paused(uint256 indexed feedId, uint256 price, uint256 drawdownBps);
    event Stopped(uint256 indexed feedId, uint256 price, uint256 drawdownBps, uint256 size);

    struct Feed {
        uint256 entryPrice;
        uint256 size;
        bool open;
        bool paused;
        bool stopped;
        bool policySet;
        uint64 epoch;
        uint16 stopBps;
        uint8 action;
        uint16 confidenceBps;
        bytes32 featuresHash;
    }

    address public owner;
    address public lastReactive;
    mapping(uint256 feedId => Feed) public feeds;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor(IPayable callbackProxy_, address reactive_) payable AbstractCallback(callbackProxy_, reactive_) {
        owner = msg.sender;
    }

    function coverDebt() external {
        _coverDebt();
    }

    function openPosition(uint256 feedId, uint256 entryPrice, uint256 size) external onlyOwner {
        if (entryPrice == 0 || size == 0) revert ZeroValue();
        Feed storage feed = feeds[feedId];
        if (feed.entryPrice != 0) revert AlreadyOpen();
        feed.entryPrice = entryPrice;
        feed.size = size;
        feed.open = true;
        emit PositionOpened(feedId, entryPrice, size);
    }

    function syncPolicy(
        address reactive,
        uint256 feedId,
        uint64 epoch,
        uint16 stopBps,
        uint8 action,
        uint16 confidenceBps,
        bytes32 featuresHash
    ) external onlyServiceProvider onlyCallbackSender(reactive) {
        lastReactive = reactive;
        if (stopBps < AegisMath.MIN_STOP_BPS || stopBps > AegisMath.MAX_STOP_BPS) revert StopOutOfRange(stopBps);
        if (confidenceBps < AegisMath.MIN_CONFIDENCE_BPS) revert ConfidenceTooLow(confidenceBps);
        if (action > AegisMath.PAUSE) revert BadAction(action);
        Feed storage feed = feeds[feedId];
        if (!feed.open) revert FeedNotOpen();
        if (feed.policySet && epoch <= feed.epoch) revert EpochMismatch(epoch, feed.epoch);
        feed.epoch = epoch;
        feed.stopBps = stopBps;
        feed.action = action;
        feed.confidenceBps = confidenceBps;
        feed.featuresHash = featuresHash;
        feed.policySet = true;
        emit PolicySynced(feedId, epoch, stopBps, action, confidenceBps, featuresHash);
    }

    function protect(
        address reactive,
        uint256 feedId,
        uint256 price,
        uint64 updatedAt,
        uint64 epoch,
        uint8 action
    ) external onlyServiceProvider onlyCallbackSender(reactive) {
        lastReactive = reactive;
        Feed storage feed = feeds[feedId];
        if (!feed.open || feed.stopped) revert FeedNotOpen();
        if (!feed.policySet) revert PolicyNotSet();
        if (epoch != feed.epoch) revert EpochMismatch(epoch, feed.epoch);
        if (action != feed.action) revert ActionMismatch(action, feed.action);
        if (action == AegisMath.HOLD) revert HoldDoesNotProtect();
        if (updatedAt > block.timestamp + AegisMath.FUTURE_SKEW) revert FuturePrice(updatedAt);
        if (block.timestamp > updatedAt && block.timestamp - uint256(updatedAt) > AegisMath.MAX_PRICE_AGE) {
            revert StalePrice(updatedAt, uint64(block.timestamp));
        }
        uint256 drawdown = AegisMath.drawdownBps(feed.entryPrice, price);
        uint256 required = AegisMath.triggerBps(feed.stopBps, action);
        if (drawdown < required) revert ConditionsNotMet(drawdown, required);
        if (action == AegisMath.PAUSE) {
            feed.paused = true;
            emit Paused(feedId, price, drawdown);
            return;
        }
        feed.open = false;
        feed.stopped = true;
        feed.paused = true;
        emit Stopped(feedId, price, drawdown, feed.size);
    }
}
