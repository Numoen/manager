// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { ERC20 } from "numoen-core/ERC20.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";
import { SafeTransferLib } from "../src/libraries/SafeTransferLib.sol";

contract DeployScript is Script {
    function run() public {
        address celo = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        address cusd = 0x765DE816845861e75A25fCA122bb6898B8B1282a;

        address token = cusd;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        console2.log(ERC20(token).balanceOf(vm.addr(pk)));
        vm.broadcast(pk);
        SafeTransferLib.safeTransfer(token, address(0xff - 2), 10**15);
        console2.log(ERC20(token).balanceOf(address(0xff - 2)));
        console2.log(ERC20(token).balanceOf(vm.addr(pk)));
    }
}
