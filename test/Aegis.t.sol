// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AegisMath } from "../src/AegisMath.sol";
import { AegisOrigin } from "../src/origin/AegisOrigin.sol";
import { AegisReactive } from "../src/reactive/AegisReactive.sol";
import { AegisVault } from "../src/destination/AegisVault.sol";
import { MockSystem } from "../src/local/MockSystem.sol";
import { CallbackRelay } from "../src/local/CallbackRelay.sol";

contract AegisTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    uint256 internal constant REACTIVE_IGNORE =
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;
    uint256 internal constant ORIGIN_CHAIN = 11_155_111;
    uint256 internal constant DEST_CHAIN = 84_532;
    uint256 internal constant FEED = 1;
    uint256 internal constant ENTRY = 20_000;
    uint256 internal constant SIZE = 1_000_000;

    AegisOrigin internal origin;
    AegisReactive internal aegis;
    AegisVault internal vault;
    CallbackRelay internal relay;

    function setUp() public {
        vm.warp(1_700_000_000);
        MockSystem impl = new MockSystem();
        vm.etch(SYSTEM, address(impl).code);

        origin = new AegisOrigin();
        aegis = new AegisReactive(ORIGIN_CHAIN, DEST_CHAIN, address(origin));
        relay = new CallbackRelay();
        vault = new AegisVault(IPayable(payable(address(relay))), address(aegis));
        aegis.setVault(address(vault));
    }

    function test_subscribeThreeTopics() public view {
        MockSystem system = MockSystem(payable(SYSTEM));
        assertEq(system.subscriptionCount(), 3);
        assertEq(address(aegis._SERVICE_PROVIDER()), SYSTEM);

        uint256 positionTopic = uint256(keccak256("PositionOpened(uint256,uint256,uint256)"));
        uint256 priceTopic = uint256(keccak256("PriceUpdated(uint256,uint256,uint64)"));
        uint256 policyTopic = uint256(keccak256("PolicyPosted(uint256,uint64,uint16,uint8,uint16,bytes32)"));
        bool sawPosition;
        bool sawPrice;
        bool sawPolicy;
        for (uint256 i = 0; i < 3; ++i) {
            MockSystem.Subscription memory sub = system.getSubscription(i);
            assertEq(sub.subscriber, address(aegis));
            assertEq(sub.chainId, ORIGIN_CHAIN);
            assertEq(sub.origin, address(origin));
            assertEq(sub.topic1, REACTIVE_IGNORE);
            assertEq(sub.topic2, REACTIVE_IGNORE);
            assertEq(sub.topic3, REACTIVE_IGNORE);
            assertTrue(sub.active);
            if (sub.topic0 == positionTopic) sawPosition = true;
            if (sub.topic0 == priceTopic) sawPrice = true;
            if (sub.topic0 == policyTopic) sawPolicy = true;
        }
        assertTrue(sawPosition && sawPrice && sawPolicy);
    }

    function test_reactRejectsNonSystem() public {
        vm.recordLogs();
        origin.pushPrice(FEED, ENTRY, uint64(block.timestamp));
        IReactive.LogRecord memory log_ = _takeLog();
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address,address)", address(this), SYSTEM));
        aegis.react(log_);
    }

    function test_triggerMath() public pure {
        assertEq(AegisMath.drawdownBps(ENTRY, 18_000), 1000);
        assertEq(AegisMath.drawdownBps(ENTRY, 19_000), 500);
        assertEq(AegisMath.drawdownBps(ENTRY, 19_002), 499);
        assertEq(AegisMath.drawdownBps(ENTRY, ENTRY), 0);
        assertEq(AegisMath.triggerBps(1000, AegisMath.ARM), 1000);
        assertEq(AegisMath.triggerBps(1000, AegisMath.PAUSE), 500);
        assertEq(AegisMath.triggerBps(101, AegisMath.PAUSE), 50);
        assertEq(AegisMath.triggerBps(1000, AegisMath.HOLD), type(uint256).max);
        assertEq(AegisMath.clampStop(1), 100);
        assertEq(AegisMath.clampStop(50_000), 2000);
    }

    function testFuzz_drawdownCapsAtOneHundredPercent(uint256 entry, uint256 price) public pure {
        entry = bound(entry, 1, type(uint128).max);
        price = bound(price, 0, type(uint128).max);
        uint256 drawdown = AegisMath.drawdownBps(entry, price);
        assertLe(drawdown, 10_000);
        if (price >= entry) assertEq(drawdown, 0);
    }

    function test_featureHashVector() public pure {
        uint256[5] memory xs = [uint256(1), 2, 3, 4, 5];
        assertEq(keccak256(abi.encode(xs)), hex"5917e5a395fb9b454434de59651d36822a9e29c5ec57474df3e67937b969460c");
    }

    function test_injectsReactiveAddressIntoFirstArgument() public view {
        bytes memory payload = abi.encodeWithSignature("protect(address,uint256)", address(0), uint256(7));
        bytes memory patched = relay.inject(payload, address(aegis));
        bytes memory args = new bytes(patched.length - 4);
        for (uint256 i = 0; i < args.length; ++i) {
            args[i] = patched[i + 4];
        }
        (address who, uint256 n) = abi.decode(args, (address, uint256));
        assertEq(who, address(aegis));
        assertEq(n, 7);
        bytes4 sel;
        assembly {
            sel := mload(add(patched, 32))
        }
        assertEq(sel, bytes4(keccak256("protect(address,uint256)")));
    }

    function test_positionAndPriceRoundTrip() public {
        _open(ENTRY);
        (uint256 entryPrice, uint256 size, uint256 lastPrice, bool open,,,,,,,,) = aegis.feeds(FEED);
        assertEq(entryPrice, ENTRY);
        assertEq(size, SIZE);
        assertEq(lastPrice, ENTRY);
        assertTrue(open);

        _price(19_500);
        (,, lastPrice,,,,,,,,,) = aegis.feeds(FEED);
        assertEq(lastPrice, 19_500);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), 0);
    }

    function test_armedStopRequestsProtectAndVaultCloses() public {
        _open(ENTRY);
        _acceptPolicy(1, 1000, AegisMath.ARM, 8000);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), 1);
        _relayLatest();
        assertEq(vault.lastReactive(), address(aegis));

        _price(18_000);
        MockSystem system = MockSystem(payable(SYSTEM));
        assertEq(system.callbackCount(), 2);
        assertEq(system.lastChainId(), DEST_CHAIN);
        assertEq(system.lastRecipient(), address(vault));
        assertEq(system.lastSender(), address(aegis));
        assertEq(system.lastGasLimit(), 1_000_000);
        (address placeholder, uint256 feedId,,,,) =
            abi.decode(_args(system.lastPayload()), (address, uint256, uint256, uint64, uint64, uint8));
        assertEq(placeholder, address(0));
        assertEq(feedId, FEED);

        _relayLatest();
        (uint256 entryPrice,, bool open, bool paused, bool stopped,,,,,,) = vault.feeds(FEED);
        assertEq(entryPrice, ENTRY);
        assertFalse(open);
        assertTrue(paused);
        assertTrue(stopped);
        assertEq(vault.lastReactive(), address(aegis));
    }

    function test_secondArmDoesNotDoubleSend() public {
        _open(ENTRY);
        _acceptPolicy(1, 1000, AegisMath.ARM, 8000);
        _relayLatest();
        _price(18_000);
        uint256 callbacks = MockSystem(payable(SYSTEM)).callbackCount();
        _price(17_000);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), callbacks);
    }

    function test_pauseFiresAtHalfDrawdownAndDoesNotClose() public {
        _open(ENTRY);
        _acceptPolicy(1, 1000, AegisMath.PAUSE, 8000);
        _relayLatest();
        _price(19_002);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), 1);
        _price(19_000);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), 2);
        _relayLatest();
        (,, bool open, bool paused, bool stopped,,,,,,) = vault.feeds(FEED);
        assertTrue(open);
        assertTrue(paused);
        assertFalse(stopped);
    }

    function test_holdDoesNotFire() public {
        _open(ENTRY);
        _acceptPolicy(1, 100, AegisMath.HOLD, 8000);
        _relayLatest();
        uint256 callbacks = MockSystem(payable(SYSTEM)).callbackCount();
        _price(1);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), callbacks);
        (bool fire,,,) = aegis.evaluate(FEED, 1);
        assertFalse(fire);
    }

    function test_lowConfidencePolicyIsRejected() public {
        _open(ENTRY);
        uint256 before = MockSystem(payable(SYSTEM)).callbackCount();
        vm.recordLogs();
        origin.postPolicy(FEED, 1, 1000, AegisMath.ARM, 5499, keccak256("low"));
        _deliverLatest();
        (,,,,,,, uint64 epoch,,,,) = aegis.feeds(FEED);
        assertEq(epoch, 0);
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), before);
    }

    function test_stopIsClampedBeforeCallback() public {
        _open(ENTRY);
        _acceptPolicy(1, 50_000, AegisMath.ARM, 9000);
        (,,,,,,, uint64 epoch, uint16 stopBps,,,) = aegis.feeds(FEED);
        assertEq(epoch, 1);
        assertEq(stopBps, 2000);
        _relayLatest();
        (,,,,,,, uint16 vaultStop,,,) = vault.feeds(FEED);
        assertEq(vaultStop, 2000);
    }

    function test_staleEpochIsRejected() public {
        _open(ENTRY);
        _acceptPolicy(2, 1000, AegisMath.ARM, 8000);
        uint256 callbacks = MockSystem(payable(SYSTEM)).callbackCount();
        vm.recordLogs();
        origin.postPolicy(FEED, 2, 100, AegisMath.PAUSE, 9000, keccak256("same"));
        _deliverLatest();
        assertEq(MockSystem(payable(SYSTEM)).callbackCount(), callbacks);
        (,,,,,,,, uint16 stopBps, uint8 action,,) = aegis.feeds(FEED);
        assertEq(stopBps, 1000);
        assertEq(action, AegisMath.ARM);
    }

    function test_unrelatedLogIsIgnored() public {
        _open(ENTRY);
        IReactive.LogRecord memory log_ = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(origin),
            topic0: uint256(keccak256("SomethingElse()")),
            topic1: FEED,
            topic2: 0,
            topic3: 0,
            data: abi.encode(uint256(1)),
            blockNumber: block.number,
            opCode: 2,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
        MockSystem(payable(SYSTEM)).deliver(address(aegis), log_);
        (,, uint256 lastPrice,,,,,,,,,) = aegis.feeds(FEED);
        assertEq(lastPrice, ENTRY);
    }

    function test_wrongChainIsIgnored() public {
        _open(ENTRY);
        vm.recordLogs();
        origin.pushPrice(FEED, 1, uint64(block.timestamp));
        IReactive.LogRecord memory log_ = _takeLog();
        log_.chainId = 1;
        MockSystem(payable(SYSTEM)).deliver(address(aegis), log_);
        (,, uint256 lastPrice,,,,,,,,,) = aegis.feeds(FEED);
        assertEq(lastPrice, ENTRY);
    }

    function test_vaultRejectsDirectCall() public {
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized(address,address)", address(this), address(relay)));
        vault.protect(address(aegis), FEED, 18_000, uint64(block.timestamp), 1, AegisMath.ARM);
    }

    function test_vaultRejectsWrongReactiveSender() public {
        vm.prank(address(relay));
        vm.expectRevert(abi.encodeWithSignature("CallbackNotAuthorized(address,address)", address(0xBEEF), address(aegis)));
        vault.protect(address(0xBEEF), FEED, 18_000, uint64(block.timestamp), 1, AegisMath.ARM);
    }

    function test_vaultRejectsDisagreement() public {
        _open(ENTRY);
        _acceptPolicy(1, 1000, AegisMath.ARM, 8000);
        _relayLatest();
        bytes memory payload = abi.encodeWithSignature(
            "protect(address,uint256,uint256,uint64,uint64,uint8)",
            address(0),
            FEED,
            19_000,
            uint64(block.timestamp),
            uint64(1),
            AegisMath.ARM
        );
        vm.expectRevert(abi.encodeWithSignature("ConditionsNotMet(uint256,uint256)", uint256(500), uint256(1000)));
        relay.relay(address(vault), payload, address(aegis));
        (,, bool open,, bool stopped,,,,,,) = vault.feeds(FEED);
        assertTrue(open);
        assertFalse(stopped);
    }

    function test_vaultRejectsStaleAndFuturePrices() public {
        _open(ENTRY);
        _acceptPolicy(1, 1000, AegisMath.ARM, 8000);
        _relayLatest();
        bytes memory stale = abi.encodeWithSignature(
            "protect(address,uint256,uint256,uint64,uint64,uint8)",
            address(0),
            FEED,
            18_000,
            uint64(block.timestamp - 2 hours),
            uint64(1),
            AegisMath.ARM
        );
        vm.expectRevert();
        relay.relay(address(vault), stale, address(aegis));

        bytes memory future = abi.encodeWithSignature(
            "protect(address,uint256,uint256,uint64,uint64,uint8)",
            address(0),
            FEED,
            18_000,
            uint64(block.timestamp + 1 days),
            uint64(1),
            AegisMath.ARM
        );
        vm.expectRevert();
        relay.relay(address(vault), future, address(aegis));
        (,, bool open,,,,,,,,) = vault.feeds(FEED);
        assertTrue(open);
    }

    function test_vaultRejectsStopOutsideBandWhenCalledDirectlyThroughRelay() public {
        _open(ENTRY);
        bytes memory payload = abi.encodeWithSignature(
            "syncPolicy(address,uint256,uint64,uint16,uint8,uint16,bytes32)",
            address(0),
            FEED,
            uint64(1),
            uint16(1),
            AegisMath.ARM,
            uint16(8000),
            keccak256("tiny")
        );
        vm.expectRevert(abi.encodeWithSignature("StopOutOfRange(uint16)", uint16(1)));
        relay.relay(address(vault), payload, address(aegis));
    }

    function test_coverDebtOnZeroIsSafe() public {
        aegis.coverDebt();
        vault.coverDebt();
    }

    function test_callbackSenderIsImmutable() public view {
        assertEq(vault._CALLBACK_SENDER(), address(aegis));
        assertEq(address(vault._SERVICE_PROVIDER()), address(relay));
    }

    function _open(uint256 entry) internal {
        vault.openPosition(FEED, entry, SIZE);
        vm.recordLogs();
        origin.openPosition(FEED, entry, SIZE);
        _deliverLatest();
    }

    function _acceptPolicy(uint64 epoch, uint16 stopBps, uint8 action, uint16 confidence) internal {
        vm.recordLogs();
        origin.postPolicy(FEED, epoch, stopBps, action, confidence, keccak256("policy"));
        _deliverLatest();
    }

    function _price(uint256 price) internal {
        vm.recordLogs();
        origin.pushPrice(FEED, price, uint64(block.timestamp));
        _deliverLatest();
    }

    function _deliverLatest() internal {
        MockSystem(payable(SYSTEM)).deliver(address(aegis), _takeLog());
    }

    function _relayLatest() internal {
        relay.relay(address(vault), MockSystem(payable(SYSTEM)).lastPayload(), address(aegis));
    }

    function _takeLog() internal view returns (IReactive.LogRecord memory log_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        Vm.Log memory entry = logs[0];
        log_ = IReactive.LogRecord({
            chainId: ORIGIN_CHAIN,
            contractAddress: address(origin),
            topic0: uint256(entry.topics[0]),
            topic1: entry.topics.length > 1 ? uint256(entry.topics[1]) : 0,
            topic2: entry.topics.length > 2 ? uint256(entry.topics[2]) : 0,
            topic3: entry.topics.length > 3 ? uint256(entry.topics[3]) : 0,
            data: entry.data,
            blockNumber: block.number,
            opCode: entry.topics.length,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function _args(bytes memory payload) internal pure returns (bytes memory args) {
        args = new bytes(payload.length - 4);
        for (uint256 i = 0; i < args.length; ++i) {
            args[i] = payload[i + 4];
        }
    }
}
