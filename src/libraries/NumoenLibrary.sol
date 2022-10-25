// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

library NumoenLibrary {
    function priceToReserves(
        uint256 price,
        uint256 liquidity,
        uint256 upperBound
    ) internal pure returns (uint256 r0, uint256 r1) {
        uint256 scale0 = PRBMathUD60x18.powu(price, 2);
        uint256 scale1 = 2 * (upperBound - price);

        return (PRBMathUD60x18.mul(scale0, liquidity), PRBMathUD60x18.mul(scale1, liquidity));
    }

    /// @dev uses r0 first then r1 if r0 is zero
    function reservesToPrice(
        uint256 r0,
        uint256 r1,
        uint256 liquidity,
        uint256 upperBound
    ) internal pure returns (uint256 price) {
        if (r0 == 0) {
            uint256 scale0 = PRBMathUD60x18.div(r0, liquidity);
            return PRBMathUD60x18.sqrt(scale0);
        } else {
            uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);
            return upperBound - scale1 / 2;
        }
    }

    // TODO: do these functions need to be scaled?
    function getBaseOutExactIn(
        uint256 amountSIn,
        uint256 r0,
        uint256 r1,
        uint256 upperBound
    ) internal pure returns (uint256 amountBOut) {
        uint256 a = PRBMathUD60x18.mul(amountSIn, upperBound);
        uint256 b = PRBMathUD60x18.powu(amountSIn, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(amountSIn, r1) / 2;

        amountBOut = a - b - c;
    }

    function getSpeculativeOutExactIn(
        uint256 amountBIn,
        uint256 r0,
        uint256 r1,
        uint256 upperBound
    ) internal pure returns (uint256 amountSOut) {
        uint256 a = 2 * upperBound - r1;
        uint256 b = 4 * amountBIn;
        uint256 c = PRBMathUD60x18.sqrt(PRBMathUD60x18.powu(a, 2) + b);

        amountSOut = c - a;
    }

    function getSpeculativeInExactOut(
        uint256 amountBOut,
        uint256 r0,
        uint256 r1,
        uint256 upperBound
    ) internal pure returns (uint256 amountSIn) {
        uint256 a = 2 * upperBound - r1;
        uint256 b = 4 * amountBOut;
        uint256 c = PRBMathUD60x18.sqrt(PRBMathUD60x18.powu(a, 2) - b);

        amountSIn = a - c;
    }

    function getBaseInExactOut(
        uint256 amountSOut,
        uint256 r0,
        uint256 r1,
        uint256 upperBound
    ) internal pure returns (uint256 amountBIn) {
        uint256 a = PRBMathUD60x18.mul(amountSOut, upperBound);
        uint256 b = PRBMathUD60x18.powu(amountSOut, 2) / 4;
        uint256 c = PRBMathUD60x18.mul(amountSOut, r1) / 2;

        amountBIn = a + b - c;
    }

    // function getAmountIn();

    // function getAmountOut();
}
