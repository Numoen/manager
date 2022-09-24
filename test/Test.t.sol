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

    // function testBasic() public {
    //     _mintUni(1 ether, 1 ether, cuh);
    //     _mintMaker(1 ether, 1 ether, cuh);

    //     speculative.mint(cuh, 0.1 ether);
    //     vm.prank(cuh);
    //     speculative.approve(address(router), 0.1 ether);

    //     vm.prank(cuh);

    //     router.mint(0.1 ether, address(speculative), address(base), upperBound);

    //     console2.log("user sq balance:", lendgine.balanceOf(cuh));
    //     console2.log("user spec balance:", speculative.balanceOf(cuh));

    //     // check router balances
    //     assertEq(lendgine.balanceOf(address(router)), 0);
    //     assertEq(speculative.balanceOf(address(router)), 0);
    // }

    // function testLessSlippage() public {
    //     _mintUni(10000 ether, 10000 ether, cuh);
    //     _mintMaker(50 ether, 50 ether, cuh);

    //     speculative.mint(cuh, 0.01 ether);
    //     vm.prank(cuh);
    //     speculative.approve(address(router), 0.01 ether);

    //     vm.prank(cuh);

    //     router.mint(0.01 ether, address(speculative), address(base), upperBound);

    //     console2.log("user sq balance:", lendgine.balanceOf(cuh));
    //     console2.log("user spec balance:", speculative.balanceOf(cuh));

    //     // check router balances
    //     assertEq(lendgine.balanceOf(address(router)), 0);
    //     assertEq(speculative.balanceOf(address(router)), 0);
    // }

    function testBurn() public {
        _mintUni(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, cuh);
        _mint(1 ether, cuh);

        vm.prank(cuh);
        lendgine.approve(address(router), 0.1 ether);

        vm.prank(cuh);
        router.burn(0.1 ether, address(speculative), address(base), upperBound);

        assertEq(lendgine.balanceOf(cuh), 0);
        console2.log("user spec balance:", speculative.balanceOf(cuh));

        // check router balances
        assertEq(lendgine.balanceOf(address(router)), 0);
        assertEq(speculative.balanceOf(address(router)), 0);
        // cusd: 0.6, celo: 8.4
    }

    function testMintRouter() public {
        speculative.mint(cuh, 0.1 ether);
        base.mint(cuh, 0.1 ether);

        vm.prank(cuh);
        speculative.approve(address(mintRouter), 0.1 ether);

        vm.prank(cuh);
        base.approve(address(mintRouter), 0.1 ether);

        vm.prank(cuh);
        mintRouter.mintMaker(0.1 ether, 0.1 ether, address(speculative), address(base), upperBound);
    }

    // test max slippage
}
