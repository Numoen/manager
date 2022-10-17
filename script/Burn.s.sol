// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";
import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { ERC20 } from "numoen-core/ERC20.sol";

contract Burn is Script {
    function run() public {
        address lendgineRouter = 0x87Cf4f31EE557F7188C90FE3E9b7aEDA0B805a61;
        address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        address speculative = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        uint256 upperBound = 5 ether;

        console2.log(ERC20(base).allowance(0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A, lendgineRouter));

        // uint256 pk = vm.envUint("PRIVATE_KEY");

        // vm.broadcast(pk);
        // LendgineRouter(lendgineRouter).burn(
        //     LendgineRouter.BurnParams({
        //         base: base,
        //         speculative: speculative,
        //         upperBound: upperBound,
        //         deadline: block.timestamp + 100,
        //         recipient: 0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A,
        //         amountBMax: 1020000000000000,
        //         amountSMin: 0,
        //         shares: 1000000000000000000000000000000000
        //     })
        // );
    }
}
