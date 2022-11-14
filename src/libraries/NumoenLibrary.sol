// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

/// @notice Helper functions for interacting with Numoen Core
/// @author Kyle Scott (https://github.com/Numoen/manager/blob/master/src/libraries/NumoenLibrary.sol)
library NumoenLibrary {
    /// @notice Calculates the reserves of a pair given a price
    /// @param price Exchange rate measured in base / speculative scaled by 1 ether
    /// @param liquidity Amount of liquidity shares
    /// @param upperBound Upper bound of the pair
    function priceToReserves(
        uint256 price,
        uint256 liquidity,
        uint256 upperBound
    ) internal pure returns (uint256 r0, uint256 r1) {
        uint256 scale0 = PRBMathUD60x18.powu(price, 2);
        uint256 scale1 = 2 * (upperBound - price);

        return (PRBMathUD60x18.mul(scale0, liquidity), PRBMathUD60x18.mul(scale1, liquidity));
    }

    /// @notice Calculates the price of a pair given reserves
    /// @param r1 Amount of speculative asset
    /// @param liquidity Amount of liquidity shares
    /// @param upperBound Upper bound of the pair
    /// @dev Assumes a valid set of reserves and liquidity
    function reservesToPrice(
        uint256 r1,
        uint256 liquidity,
        uint256 upperBound
    ) internal pure returns (uint256 price) {
        uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);
        return upperBound - scale1 / 2;
    }

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
        uint256 upperBound
    ) internal pure returns (uint256 amountBIn) {
        uint256 scaleSOut = PRBMathUD60x18.div(amountSOut, liquidity);
        uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);

        uint256 a = PRBMathUD60x18.mul(scaleSOut, upperBound);
        uint256 b = PRBMathUD60x18.powu(scaleSOut, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(scaleSOut, scale1) / 2;

        amountBIn = PRBMathUD60x18.mul(a + b - c, liquidity);
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
        uint256 upperBound
    ) internal pure returns (uint256 amountBOut) {
        uint256 scaleSIn = PRBMathUD60x18.div(amountSIn, liquidity);
        uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);

        uint256 a = PRBMathUD60x18.mul(scaleSIn, upperBound);
        uint256 b = PRBMathUD60x18.powu(scaleSIn, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(scaleSIn, scale1) / 2;

        amountBOut = PRBMathUD60x18.mul(a - b - c, liquidity);
    }

    struct MathParams0 {
        uint256 speculativeAmount;
        uint256 upperBound;
        uint256 price;
        uint256 slippageBps;
    }

    function determineBorrowAmount(MathParams0 memory params) internal pure returns (uint256) {
        uint256 x0 = PRBMathUD60x18.powu(params.price, 2);
        uint256 x1 = (params.upperBound - params.price) * 2;

        uint256 numerator = PRBMathUD60x18.mul(x1, params.speculativeAmount) +
            ((10000 - params.slippageBps) *
                PRBMathUD60x18.div(PRBMathUD60x18.mul(x0, params.speculativeAmount), params.price)) /
            10000;
        uint256 denominator = 2 *
            params.upperBound -
            (((10000 - params.slippageBps) * PRBMathUD60x18.div(x0, params.price)) / 10000) -
            x1;

        return PRBMathUD60x18.div(numerator, denominator);
    }
}
