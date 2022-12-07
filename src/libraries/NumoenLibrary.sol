// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

/// @notice Helper functions for interacting with Numoen Core
/// @author Kyle Scott (https://github.com/Numoen/manager/blob/master/src/libraries/NumoenLibrary.sol)
library NumoenLibrary {
    /// @notice Calculates the amount of base tokens in for a given amount of speculative tokens to be received
    /// @param amountSOut Amount of speculative tokens requested
    /// @param r1 Amount of speculative asset in the pair
    /// @param liquidity Amount of liquidity shares
    /// @param upperBound Upper bound of the pair
    /// @dev Assumes a valid set of reserves and liquidity
    function getBaseIn(
        uint256 amountSOut,
        uint256 r1,
        uint256 liquidity,
        uint256 upperBound,
        uint256 baseScaleFactor,
        uint256 speculativeScaleFactor
    ) internal pure returns (uint256 amountBIn) {
        uint256 scaleSOut = PRBMathUD60x18.div(PRBMathUD60x18.div(amountSOut, liquidity), 10**speculativeScaleFactor);
        uint256 scale1 = PRBMathUD60x18.div(PRBMathUD60x18.div(r1, liquidity), 10**speculativeScaleFactor);

        uint256 a = PRBMathUD60x18.mul(scaleSOut, upperBound);
        uint256 b = PRBMathUD60x18.powu(scaleSOut, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(scaleSOut, scale1) / 2;

        amountBIn = PRBMathUD60x18.mul(PRBMathUD60x18.mul(a + b - c, liquidity) + 1, 10**baseScaleFactor);
    }

    /// @notice Calculates the amount of base tokens out for a given amount of speculative tokens to be sold
    /// @param amountSIn Amount of speculative tokens to be traded in
    /// @param r1 Amount of speculative asset in the pair
    /// @param liquidity Amount of liquidity shares
    /// @param upperBound Upper bound of the pair
    /// @dev Assumes a valid set of reserves and liquidity
    function getBaseOut(
        uint256 amountSIn,
        uint256 r1,
        uint256 liquidity,
        uint256 upperBound,
        uint256 baseScaleFactor,
        uint256 speculativeScaleFactor
    ) internal pure returns (uint256 amountBOut) {
        uint256 scaleSIn = PRBMathUD60x18.div(PRBMathUD60x18.div(amountSIn, liquidity), 10**speculativeScaleFactor);
        uint256 scale1 = PRBMathUD60x18.div(PRBMathUD60x18.div(r1, liquidity), 10**speculativeScaleFactor);

        uint256 a = PRBMathUD60x18.mul(scaleSIn, upperBound);
        uint256 b = PRBMathUD60x18.powu(scaleSIn, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(scaleSIn, scale1) / 2;

        amountBOut = PRBMathUD60x18.mul(PRBMathUD60x18.mul(a - b - c, liquidity), 10**baseScaleFactor);
    }
}
