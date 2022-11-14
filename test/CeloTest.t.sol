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
    address _factory = 0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC;
    address cusd = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
    // address celo = 0x471EcE3750Da237f93B8E339c536989b8978a438;
    address mobi = 0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B;
    uint256 upperBound = .001 ether;

    address public immutable cuh = 0xA2d918c8b04a8bbDE6A17eD7F465090F0258c08A;

    Factory public factory = Factory(_factory);
    Lendgine public lendgine;
    // LiquidityManager liquidityManager = LiquidityManager(0x8144A4E2c3F93c55d2973015a21B930F3b636EBd);
    LendgineRouter lendgineRouter;
    Pair public pair;

    LendgineAddress.LendgineKey public key;

    function setUp() public {
        lendgineRouter = new LendgineRouter(_factory, 0x62d5b84bE28a183aBB507E125B384122D2C25fAE);

        address _lendgine = LendgineAddress.computeLendgineAddress(_factory, cusd, mobi, 18, 18, upperBound);

        address _pair = LendgineAddress.computePairAddress(_factory, cusd, mobi, 18, 18, upperBound);
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
                slippageBps: 2000
            })
        );
        uint256 borrowAmountFilter = (borrowAmount / 10**6) * 10**6;
        console2.log("out", borrowAmountFilter);

        uint256 liquidity = lendgine.convertAssetToLiquidity(amountS);
        (uint256 amountBOut, uint256 amountSOut) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        console2.log("burn amounts", amountBOut, amountSOut);
        console2.log(amountSOut + PRBMathUD60x18.mul(price, amountBOut));

        console2.log("totalAmount", amountS + borrowAmountFilter);
        vm.prank(cuh);
        lendgineRouter.mint(
            LendgineRouter.MintParams({
                base: address(cusd),
                speculative: address(mobi),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                price: price,
                liquidity: liquidity,
                sharesMin: 0,
                borrowAmount: borrowAmountFilter,
                slippageBps: 50,
                recipient: cuh,
                deadline: block.timestamp + 60
            })
        );
    }
}
