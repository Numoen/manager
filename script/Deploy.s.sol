// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";
import { CREATE3Factory } from "create3-factory/CREATE3Factory.sol";

contract DeployScript is Script {
    function run() public {
        CREATE3Factory create3 = CREATE3Factory(vm.envAddress("CREATE3"));

        address factory = vm.envAddress("FACTORY");

        address uniFactory = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
        address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        create3.deploy(
            keccak256("LiquidityManager1"),
            bytes.concat(type(LiquidityManager).creationCode, abi.encode(factory, weth))
        );

        create3.deploy(
            keccak256("LendgineRouter1"),
            bytes.concat(type(LendgineRouter).creationCode, abi.encode(factory, uniFactory, weth))
        );
        vm.stopBroadcast();
    }
}
