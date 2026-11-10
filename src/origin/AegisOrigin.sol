// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title AegisOrigin
/// @notice Mock origin-chain emitter. On a deployment this is the contract Reactive subscribes to.
/// @dev The owner stands in for two roles that production would split: the price oracle and the
///      policy operator who posts the off-chain scorer's output. This MVP does not integrate a
///      live oracle.
contract AegisOrigin {
    error NotOwner(address caller);
    error ZeroValue();
    error BadAction(uint8 action);
    error BadEpoch();

    event PositionOpened(uint256 indexed feedId, uint256 entryPrice, uint256 size);
    event PriceUpdated(uint256 indexed feedId, uint256 price, uint64 updatedAt);
    event PolicyPosted(
        uint256 indexed feedId,
        uint64 epoch,
        uint16 stopBps,
        uint8 action,
        uint16 confidenceBps,
        bytes32 featuresHash
    );

    struct OriginFeed {
        uint256 entryPrice;
        uint256 size;
        uint256 lastPrice;
        uint64 lastUpdatedAt;
        uint64 lastEpoch;
    }

    address public owner;
    mapping(uint256 feedId => OriginFeed) public feeds;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function openPosition(uint256 feedId, uint256 entryPrice, uint256 size) external onlyOwner {
        if (entryPrice == 0 || size == 0) revert ZeroValue();
        OriginFeed storage feed = feeds[feedId];
        feed.entryPrice = entryPrice;
        feed.size = size;
        emit PositionOpened(feedId, entryPrice, size);
    }

    function pushPrice(uint256 feedId, uint256 price, uint64 updatedAt) external onlyOwner {
        if (price == 0) revert ZeroValue();
        OriginFeed storage feed = feeds[feedId];
        feed.lastPrice = price;
        feed.lastUpdatedAt = updatedAt;
        emit PriceUpdated(feedId, price, updatedAt);
    }

    function postPolicy(
        uint256 feedId,
        uint64 epoch,
        uint16 stopBps,
        uint8 action,
        uint16 confidenceBps,
        bytes32 featuresHash
    ) external onlyOwner {
        if (epoch == 0) revert BadEpoch();
        if (action > 2) revert BadAction(action);
        feeds[feedId].lastEpoch = epoch;
        emit PolicyPosted(feedId, epoch, stopBps, action, confidenceBps, featuresHash);
    }
}
