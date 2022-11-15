pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";
import { LendgineRouter } from "../src/LendgineRouter.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { ERC20 } from "numoen-core/ERC20.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { NumoenLibrary } from "../src/libraries/NumoenLibrary.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";
import { SafeTransferLib } from "../src/libraries/SafeTransferLib.sol";

contract LiquidityManagerTest is Test, CallbackHelper {
    address cusd = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    // address celo = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    address mobi = 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B;
    uint256 upperBound = .001 ether;

    address public immutable cuh = 0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A;

    Factory public factory = Factory(0x4Ef9A0Eea3B521478762Df70d6127eeF3d386B22);
    Lendgine public lendgine;
    LendgineRouter lendgineRouter;
    Pair public pair;

    LendgineAddress.LendgineKey public key;

    function setUp() public {
        lendgineRouter = new LendgineRouter(address(factory), 0x62d5b84bE28a183aBB507E125B384122D2C25fAE);

        address _lendgine = LendgineAddress.computeLendgineAddress(address(factory), cusd, mobi, 18, 18, upperBound);

        address _pair = LendgineAddress.computePairAddress(address(factory), cusd, mobi, 18, 18, upperBound);
        console2.log(_lendgine, _pair);
        lendgine = Lendgine(_lendgine);
        pair = Pair(_pair);
    }

    function testFork() public {
        uint256 amountS = 1 ether;
        uint256 price = 0.00025 ether;

        vm.prank(cuh);
        ERC20(mobi).approve(address(lendgineRouter), amountS);

        uint256 borrowAmount = NumoenLibrary.determineBorrowAmount(
            NumoenLibrary.MathParams0({
                speculativeAmount: amountS,
                upperBound: upperBound,
                price: price,
                slippageBps: 200
            })
        );
        // uint256 borrowAmountFilter = (borrowAmount / 10**9) * 10**9;
        // console2.log(borrowAmountFilter);

        // uint256 liquidity = lendgine.convertAssetToLiquidity(amountS);
        // console2.log(liquidity);
        // uint256 shares = lendgine.convertLiquidityToShare(liquidity);
        // console2.log(shares);

        // vm.prank(cuh);
        // lendgineRouter.mint(
        //     LendgineRouter.MintParams({
        //         base: address(cusd),
        //         speculative: address(mobi),
        //         baseScaleFactor: 18,
        //         speculativeScaleFactor: 18,
        //         upperBound: upperBound,
        //         liquidity: liquidity,
        //         sharesMin: 0,
        //         borrowAmount: borrowAmountFilter,
        //         recipient: cuh,
        //         deadline: block.timestamp + 60
        //     })
        // );

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), 500 ether);
        // console2.log("pair", pair.totalSupply());
        // console2.log(ERC20(cusd).balanceOf(address(pair)), ERC20(mobi).balanceOf(address(pair)));

        vm.prank(cuh);
        lendgineRouter.burn(
            LendgineRouter.BurnParams({
                base: address(cusd),
                speculative: address(mobi),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                liquidityMax: 501 ether,
                shares: 500 ether,
                recipient: cuh,
                deadline: block.timestamp + 60
            })
        );
    }
}
