// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

library NumoenLibrary {
    function getAmountOut(
        uint256 amountIn,
        bool specForBase,
        uint256 speculativeReserves,
        uint256 baseReserves
    ) internal pure returns (uint256 amountOut) {
        amountOut = amountIn;
    }

    function getAmountIn(
        uint256 amountOut,
        bool specForBase,
        uint256 speculativeReserves,
        uint256 baseReserves
    ) internal pure returns (uint256 amountIn) {
        amountIn = amountOut;
    }

    function getMinCollateralRatio(uint256 upperBound) internal pure returns (uint256) {
        return 2 * upperBound;
    }
}
