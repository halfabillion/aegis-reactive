// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console2 } from "forge-std/Script.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AegisOrigin } from "../src/origin/AegisOrigin.sol";
import { AegisVault } from "../src/destination/AegisVault.sol";
import { AegisReactive } from "../src/reactive/AegisReactive.sol";

contract EstimateBase is Script {
    function run() external {
        vm.deal(msg.sender, 1 ether);
        vm.startBroadcast();
        AegisOrigin origin = new AegisOrigin();
        AegisVault vault = new AegisVault(
            IPayable(payable(0x476F44b11F5C942c58f4c8E3d0300E5710743585)),
            address(0x1111111111111111111111111111111111111111)
        );
        vault.openPosition(1, 100_000_000_000, 1_000_000);
        origin.openPosition(1, 100_000_000_000, 1_000_000);
        origin.postPolicy(1, 1, 911, 1, 7391, bytes32(uint256(1)));
        origin.pushPrice(1, 100_000_000_000, uint64(block.timestamp));
        origin.postPolicy(1, 2, 458, 0, 2557, bytes32(uint256(2)));
        origin.postPolicy(1, 3, 432, 2, 6506, bytes32(uint256(3)));
        origin.pushPrice(1, 97_029_900_000, uint64(block.timestamp));
        origin.postPolicy(1, 4, 270, 1, 7721, bytes32(uint256(4)));
        origin.pushPrice(1, 80_798_284_477, uint64(block.timestamp));
        vm.stopBroadcast();
    }
}

contract EstimateLasna is Script {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;

    function run() external {
        vm.deal(msg.sender, 100 ether);
        vm.startBroadcast();
        AegisReactive reactive = new AegisReactive(84532, 84532, address(0x2222222222222222222222222222222222222222));
        reactive.setVault(address(0x3333333333333333333333333333333333333333));
        vm.stopBroadcast();

        _react(reactive, _position());
        _react(reactive, _policy(1, 911, 1, 7391));
        _react(reactive, _price(100_000_000_000));
        _react(reactive, _policy(2, 458, 0, 2557));
        _react(reactive, _policy(3, 432, 2, 6506));
        _react(reactive, _price(97_029_900_000));
        _react(reactive, _policy(4, 270, 1, 7721));
        _react(reactive, _price(80_798_284_477));
    }

    function _react(AegisReactive reactive, IReactive.LogRecord memory log_) internal {
        uint256 before = gasleft();
        vm.prank(SYSTEM);
        reactive.react(log_);
        console2.log("react gas", before - gasleft());
    }

    function _base(uint256 topic0, uint256 topic1, bytes memory data) internal pure returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: 84532,
            contractAddress: address(0x2222222222222222222222222222222222222222),
            topic0: topic0,
            topic1: topic1,
            topic2: 0,
            topic3: 0,
            data: data,
            blockNumber: 1,
            opCode: 2,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function _position() internal pure returns (IReactive.LogRecord memory) {
        return _base(
            uint256(keccak256("PositionOpened(uint256,uint256,uint256)")),
            1,
            abi.encode(uint256(100_000_000_000), uint256(1_000_000))
        );
    }

    function _policy(uint64 epoch, uint16 stopBps, uint8 action, uint16 confidence)
        internal
        pure
        returns (IReactive.LogRecord memory)
    {
        return _base(
            uint256(keccak256("PolicyPosted(uint256,uint64,uint16,uint8,uint16,bytes32)")),
            1,
            abi.encode(epoch, stopBps, action, confidence, bytes32(uint256(epoch)))
        );
    }

    function _price(uint256 price) internal view returns (IReactive.LogRecord memory) {
        return _base(
            uint256(keccak256("PriceUpdated(uint256,uint256,uint64)")),
            1,
            abi.encode(price, uint64(block.timestamp))
        );
    }
}
