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
        address factory = 0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC;
        address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        address speculative = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        uint256 upperBound = 5 ether;

        LiquidityManager liquidityManager = LiquidityManager(0x8144A4E2c3F93c55d2973015a21B930F3b636EBd);

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
                amount0Min: 10**14,
                amount1Min: 8 * 10**14,
                liquidity: 10**14,
                recipient: 0x59A6AbC89C158ef88d5872CaB4aC3B08474883D9,
                deadline: block.timestamp + 60
            })
        );
        // console2.log(tokenID);
    }
}
