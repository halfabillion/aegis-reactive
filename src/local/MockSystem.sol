// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";

/// @title MockSystem
/// @notice Local stand-in for the Omni system contract at 0x8888…8888.
/// @dev Tests etch this runtime code onto that address. It records subscribe() and
///      requestCallbackV_1_0(), and it can deliver a log by calling react(). It does not
///      bill gas, and it is not the contract deployed on Lasna.
contract MockSystem is ISystemContract {
    error InvalidCallbackVersion();

    struct Subscription {
        address subscriber;
        uint256 chainId;
        address origin;
        uint256 topic0;
        uint256 topic1;
        uint256 topic2;
        uint256 topic3;
        bool active;
    }

    struct CallbackJob {
        address sender;
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    event CallbackRequest(
        uint256 indexed chainId,
        address indexed sender,
        address indexed recipient,
        CallbackVersion version,
        bytes configuration
    );

    mapping(address => uint256) private _debt;
    Subscription[] private _subs;
    CallbackJob[] private _jobs;

    receive() external payable { }

    function debt(address contract_) external view returns (uint256 debt_) {
        return _debt[contract_];
    }

    function subscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external {
        _subs.push(
            Subscription({
                subscriber: msg.sender,
                chainId: chainId_,
                origin: contract_,
                topic0: topic0_,
                topic1: topic1_,
                topic2: topic2_,
                topic3: topic3_,
                active: true
            })
        );
    }

    function unsubscribe(
        uint256 chainId_,
        address contract_,
        uint256 topic0_,
        uint256 topic1_,
        uint256 topic2_,
        uint256 topic3_
    ) external {
        uint256 length = _subs.length;
        for (uint256 i = 0; i < length; ++i) {
            Subscription storage sub = _subs[i];
            if (
                sub.active && sub.subscriber == msg.sender && sub.chainId == chainId_ && sub.origin == contract_
                    && sub.topic0 == topic0_ && sub.topic1 == topic1_ && sub.topic2 == topic2_ && sub.topic3 == topic3_
            ) {
                sub.active = false;
            }
        }
    }

    function requestCallback(CallbackVersion version_, bytes memory config_) external {
        if (version_ != CallbackVersion.V_1_0) revert InvalidCallbackVersion();
        CallbackConfiguration_V_1_0 memory config = abi.decode(config_, (CallbackConfiguration_V_1_0));
        _push(config);
    }

    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config_) external {
        _push(config_);
    }

    function subscriptionCount() external view returns (uint256) {
        return _subs.length;
    }

    function getSubscription(uint256 index) external view returns (Subscription memory) {
        return _subs[index];
    }

    function callbackCount() external view returns (uint256) {
        return _jobs.length;
    }

    function getCallback(uint256 index)
        external
        view
        returns (address sender, uint256 chainId, address recipient, uint64 gasLimit, bytes memory payload)
    {
        CallbackJob storage job = _jobs[index];
        return (job.sender, job.chainId, job.recipient, job.gasLimit, job.payload);
    }

    function lastSender() external view returns (address) {
        return _jobs[_jobs.length - 1].sender;
    }

    function lastChainId() external view returns (uint256) {
        return _jobs[_jobs.length - 1].chainId;
    }

    function lastRecipient() external view returns (address) {
        return _jobs[_jobs.length - 1].recipient;
    }

    function lastGasLimit() external view returns (uint64) {
        return _jobs[_jobs.length - 1].gasLimit;
    }

    function lastPayload() external view returns (bytes memory) {
        return _jobs[_jobs.length - 1].payload;
    }

    /// @notice What the real system contract does when a matching log arrives: call react().
    function deliver(address reactive, IReactive.LogRecord calldata log_) external {
        IReactive(payable(reactive)).react(log_);
    }

    function _push(CallbackConfiguration_V_1_0 memory config_) internal {
        _jobs.push(
            CallbackJob({
                sender: msg.sender,
                chainId: config_.chainId,
                recipient: config_.recipient,
                gasLimit: config_.gasLimit,
                payload: config_.payload
            })
        );
        emit CallbackRequest(
            config_.chainId, msg.sender, config_.recipient, CallbackVersion.V_1_0, abi.encode(config_)
        );
    }
}
