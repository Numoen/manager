// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { TestHelper } from "./utils/TestHelper.sol";
import "forge-std/console2.sol";

import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

contract Test is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testBasic() public {
        _mintUni(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, cuh);

        speculative.mint(cuh, 0.1 ether);
        vm.prank(cuh);
        speculative.approve(address(router), 0.1 ether);

        vm.prank(cuh);

        router.mint(0.1 ether, address(speculative), address(base), upperBound);
    }
}
