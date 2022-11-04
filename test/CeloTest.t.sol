pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { ERC20 } from "numoen-core/ERC20.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";
import { SafeTransferLib } from "../src/libraries/SafeTransferLib.sol";

contract LiquidityManagerTest is Test, CallbackHelper {
    address _factory = 0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC;
    address cusd = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    address celo = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    address mobi = 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B;
    uint256 upperBound = 5 ether;

    address public immutable cuh = 0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A;

    Factory public factory = Factory(_factory);
    Lendgine public lendgine;
    LiquidityManager liquidityManager = LiquidityManager(0x8144A4E2c3F93c55d2973015a21B930F3b636EBd);
    Pair public pair;

    LendgineAddress.LendgineKey public key;

    function setUp() public {
        factory = new Factory();

        address _lendgine = LendgineAddress.computeLendgineAddress(_factory, cusd, celo, 18, 18, upperBound);

        address _pair = LendgineAddress.computePairAddress(_factory, cusd, celo, 18, 18, upperBound);
        lendgine = Lendgine(_lendgine);
        pair = Pair(_pair);
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "STF");
    }

    function testFork() public {
        address token = celo;

        vm.prank(cuh);
        ERC20(token).approve(address(this), 10**18);

        uint256 allowanceBefore = ERC20(token).allowance(cuh, address(this));
        uint256 balanceBefore = ERC20(token).balanceOf(cuh);

        SafeTransferLib.safeTransferFrom(token, cuh, address(pair), 10**16);

        uint256 allowanceAfter = ERC20(token).allowance(cuh, address(this));
        uint256 balanceAfter = ERC20(token).balanceOf(cuh);

        console2.log("allowance dif", allowanceBefore - allowanceAfter);
        console2.log("balance dif", balanceBefore - balanceAfter);
    }
}
