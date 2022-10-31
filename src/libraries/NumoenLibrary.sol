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

    /// @dev Assumes a valid set of reserves and liquidity
    function reservesToPrice(
        uint256 r1,
        uint256 liquidity,
        uint256 upperBound
    ) internal pure returns (uint256 price) {
        uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);
        return upperBound - scale1 / 2;
    }

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
}
