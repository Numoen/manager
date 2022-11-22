// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import "forge-std/console2.sol";

// import { LiquidityManager } from "../src/LiquidityManager.sol";
// import { LendgineRouter } from "../src/LendgineRouter.sol";

// contract DeployScript is Script {
//     function run() public {
//         address factory = 0x60BA0a7DCd2caa3Eb171f0A8692A37d34900E247;
//         address uniFactory = 0x62d5b84bE28a183aBB507E125B384122D2C25fAE;

//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         vm.broadcast(pk);
//         new LiquidityManager(factory);

//         // vm.broadcast(pk);
//         // new LendgineRouter(factory, uniFactory);
//     }
// }
