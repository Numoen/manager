// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x95c62A69B6a7da59318256B2ef8a39fda347F7B2;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        new LiquidityManager(factory);

        vm.broadcast(pk);
        new LendgineRouter(factory);
    }
}
