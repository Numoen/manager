// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x2CDb7D13a409588bbB47a9357f9c9dD61aefbf24;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        new LiquidityManager(factory);

        vm.broadcast(pk);
        new LendgineRouter(factory);
    }
}
