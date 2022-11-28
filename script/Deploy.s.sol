// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x926DE2040e0f0DCC6524d3cFADf25A59A8f16Ee7;
        address uniFactory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
        address weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        // vm.broadcast(pk);
        // new LiquidityManager(factory, weth);

        vm.broadcast(pk);
        new LendgineRouter(factory, uniFactory, weth);
    }
}
