// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { ERC20 } from "numoen-core/ERC20.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";
import { SafeTransferLib } from "../src/libraries/SafeTransferLib.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x60BA0a7DCd2caa3Eb171f0A8692A37d34900E247;
        address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        address speculative = 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B;
        uint256 upperBound = 0.001 ether;

        LiquidityManager liquidityManager = LiquidityManager(0x63F54ec45559e185d8bcE0164189bdAfA273596f);

        address pair = LendgineAddress.computePairAddress(factory, base, speculative, 18, 18, upperBound);
        address lendgine = LendgineAddress.computeLendgineAddress(factory, base, speculative, 18, 18, upperBound);

        uint256 pk = vm.envUint("PRIVATE_KEY");

        // vm.broadcast(pk);
        // ERC20(base).approve(address(liquidityManager), 10**16);
        // vm.broadcast(pk);
        // ERC20(speculative).approve(address(liquidityManager), 8 * 10**16);

        vm.broadcast(pk);
        uint256 tokenID = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                amount0Min: 0,
                amount1Min: 0,
                liquidity: 1 ether,
                recipient: vm.addr(pk),
                deadline: block.timestamp + 60
            })
        );
        // console2.log(tokenID);
    }
}
