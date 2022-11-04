pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract FlashTest is Test {
    uint256 upperBound = 5 ether;
    uint256 price = 1 ether;
    uint256 m = 2 ether;
    uint256 u0 = 100 ether;
    uint256 u1 = 100 ether;

    function testMath() public {
        uint256 x = upperBound - price;
        uint256 y = PRBMathUD60x18.powu(price, 2);

        uint256 a = (997 * 2 * PRBMathUD60x18.mul(y, upperBound)) / 1000; // negative
        uint256 b = (997 *
            4 *
            PRBMathUD60x18.mul(PRBMathUD60x18.mul(x, upperBound), u0) +
            997 *
            2 *
            PRBMathUD60x18.mul(PRBMathUD60x18.mul(y, upperBound), u1) -
            997 *
            2 *
            PRBMathUD60x18.mul(PRBMathUD60x18.mul(y, upperBound), m)) / 1000;
        uint256 c = (997 *
            4 *
            PRBMathUD60x18.mul(PRBMathUD60x18.mul(PRBMathUD60x18.mul(x, upperBound), u0), m) +
            997 *
            2 *
            PRBMathUD60x18.mul(PRBMathUD60x18.mul(PRBMathUD60x18.mul(y, upperBound), u1), m) +
            (997 * 997 * 8 * PRBMathUD60x18.mul(PRBMathUD60x18.mul(PRBMathUD60x18.powu(upperBound, 2), x), y)) /
            1000) / 1000;

        console2.log("a", a);
        console2.log("b", b);
        console2.log("c", c);

        uint256 inner = PRBMathUD60x18.sqrt(PRBMathUD60x18.powu(b, 2) + 4 * PRBMathUD60x18.mul(a, c));

        console2.log("inner", inner);

        uint256 numerator = inner - b;
        uint256 denominator = 2 * a;

        uint256 borrowAmount = PRBMathUD60x18.div(numerator, denominator);
        console2.log("borrowAmount", borrowAmount);
    }
}
