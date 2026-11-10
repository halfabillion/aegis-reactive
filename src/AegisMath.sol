// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @notice Shared stop math for the reactive contract and the destination vault.
/// @dev Both sides use these functions so a callback cannot use a different rule than the vault.
library AegisMath {
    uint8 internal constant HOLD = 0;
    uint8 internal constant ARM = 1;
    uint8 internal constant PAUSE = 2;

    uint16 internal constant MIN_CONFIDENCE_BPS = 5500;
    uint16 internal constant MIN_STOP_BPS = 100;
    uint16 internal constant MAX_STOP_BPS = 2000;
    uint256 internal constant MAX_PRICE_AGE = 1 hours;
    uint256 internal constant FUTURE_SKEW = 5 minutes;

    function drawdownBps(uint256 entry, uint256 price) internal pure returns (uint256) {
        if (entry == 0 || price >= entry) return 0;
        return (entry - price) * 10_000 / entry;
    }

    /// @dev PAUSE fires at half the posted stop. ARM fires at the full stop. HOLD never fires.
    function triggerBps(uint16 stopBps, uint8 action) internal pure returns (uint256) {
        if (action == PAUSE) return uint256(stopBps) / 2;
        if (action == ARM) return uint256(stopBps);
        return type(uint256).max;
    }

    function clampStop(uint16 stopBps) internal pure returns (uint16) {
        if (stopBps < MIN_STOP_BPS) return MIN_STOP_BPS;
        if (stopBps > MAX_STOP_BPS) return MAX_STOP_BPS;
        return stopBps;
    }
}
