// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";

/// @title CallbackRelay
/// @notice Local stand-in for the destination callback proxy and the Reactive signer relay.
/// @dev Omni overwrites the placeholder address in the callback so the destination can authenticate
///      the reactive contract. The docs describe that placeholder as the first address argument and
///      also as "the first 160 bits of the payload". Replacing the raw payload's first 160 bits
///      would destroy the 4-byte selector, which cannot work with onlyCallbackSender. This relay
///      overwrites the first ABI word after the selector (the address argument). That behavior is
///      what AegisVault is written for. It has not been checked against a live Lasna transaction.
contract CallbackRelay is IPayable {
    error ShortPayload();

    event Relayed(address indexed target, address indexed reactiveSender);

    mapping(address => uint256) private _debt;

    receive() external payable { }

    function debt(address contract_) external view returns (uint256 debt_) {
        return _debt[contract_];
    }

    function inject(bytes calldata payload, address sender) external pure returns (bytes memory) {
        return _inject(payload, sender);
    }

    function relay(address target, bytes calldata payload, address reactiveSender) external {
        bytes memory patched = _inject(payload, reactiveSender);
        (bool ok, bytes memory ret) = target.call(patched);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        emit Relayed(target, reactiveSender);
    }

    function _inject(bytes memory payload, address sender) internal pure returns (bytes memory out) {
        if (payload.length < 36) revert ShortPayload();
        out = payload;
        assembly {
            // Data starts at offset 32. The first argument word starts 4 bytes later.
            mstore(add(out, 36), sender)
        }
    }
}
