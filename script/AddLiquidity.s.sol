// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Script.sol";
// import "forge-std/console2.sol";

// import { LiquidityManager } from "../src/LiquidityManager.sol";
// import { LendgineRouter } from "../src/LendgineRouter.sol";
// import { Factory } from "numoen-core/Factory.sol";
// import { Lendgine } from "numoen-core/Lendgine.sol";
// import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
// import { ERC20 } from "numoen-core/ERC20.sol";

// contract DeployScript is Script {
//     function run() public {
//         address factory = 0x519C8f2D26a656d12582f418d6B460e57867ee5e;
//         address liquidityManager = 0x9Ac00d1e4220b2c6a9E95f3F20dEE107Be771Aa2;
//         address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
//         address speculative = 0x471EcE3750Da237f93B8E339c536989b8978a438;
//         uint256 upperBound = 5 ether;

//         uint256 pk = vm.envUint("PRIVATE_KEY");
//         // ERC20(speculative).approve(liquidityManager, 40000000000000000);

//         vm.broadcast(pk);
//         (uint256 tokenID, uint256 liquidity) = LiquidityManager(liquidityManager).mint(
//             LiquidityManager.MintParams({
//                 base: base,
//                 speculative: speculative,
//                 upperBound: upperBound,
//                 tick: 5,
//                 amount0: 104821500000000000,
//                 amount1: 0,
//                 liquidityMin: 0,
//                 recipient: 0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A,
//                 deadline: block.timestamp + 100
//             })
//         );

//         console2.log(tokenID, liquidity);
//     }
// }
