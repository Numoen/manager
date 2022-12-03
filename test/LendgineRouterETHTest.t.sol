pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";
import { Payment } from "../src/Payment.sol";

import { IUniswapV2Factory } from "../src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { NumoenLibrary } from "../src/libraries/NumoenLibrary.sol";
import { PRBMath } from "prb-math/PRBMath.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { MockERC20 } from "./utils/mocks/MockERC20.sol";

import "forge-std/console2.sol";

contract LendgineRouterTest is TestHelper {
    IUniswapV2Factory public uniFactory = IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    IUniswapV2Pair public uniPair;

    LendgineRouter public lendgineRouter;

    function mint(
        address spender,
        uint256 liquidity,
        uint256 price,
        uint256 slippageBps,
        uint256 deadline
    ) public returns (address _lendgine, uint256 _shares) {
        uint256 amount = lendgine.convertLiquidityToAsset(liquidity);
        uint256 shares = lendgine.convertLiquidityToShare(liquidity);

        uint256 borrowAmount = determineBorrowAmount(
            MathParams({ speculativeAmount: amount, upperBound: upperBound, price: price, slippageBps: slippageBps })
        );
        vm.deal(spender, amount);

        vm.prank(spender);
        (_lendgine, _shares) = lendgineRouter.mint{ value: amount }(
            LendgineRouter.MintParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                liquidity: liquidity,
                sharesMin: shares,
                borrowAmount: borrowAmount,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function mintLiqETH(
        address spender,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        uint256 deadline
    ) public returns (uint256 tokenID) {
        base.mint(spender, amount0);
        vm.deal(spender, amount1);

        vm.prank(spender);
        base.approve(address(liquidityManager), amount0);

        vm.prank(spender);
        (tokenID) = liquidityManager.mint{ value: amount1 }(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                amount0Max: amount0,
                amount1Max: amount1,
                liquidity: liquidity,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function setUp() public {
        speculative = MockERC20(address(weth));
        _setUp();

        lendgineRouter = new LendgineRouter(address(factory), address(uniFactory), address(weth));

        address _uniPair = uniFactory.createPair(address(base), address(speculative));
        uniPair = IUniswapV2Pair(_uniPair);
        base.mint(_uniPair, 10000 ether);
        vm.deal(address(this), 10000 ether);
        weth.deposit{ value: 10000 ether }();
        weth.transfer(_uniPair, 10000 ether);
        uniPair.mint(address(this));
    }

    function testMintBasic() public {
        mintLiqETH(address(this), 100 ether, 800 ether, 100 ether, block.timestamp);
        (address _lendgine, uint256 _shares) = mint(cuh, 1 ether, 1 ether, 100, block.timestamp);

        uint256 liquidity = lendgine.convertShareToLiquidity(_shares);
        uint256 collateral = lendgine.convertLiquidityToAsset(liquidity);
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(1 ether, liquidity, upperBound);
        uint256 valueDebt = r1 + r0;

        assertApproxEqRel(collateral - valueDebt, 10 ether, 1 * 10**16);
        assertEq(address(lendgine), _lendgine);
        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
        assertEq(pair.buffer(), 0);
    }

    function testBurnDDos() public {
        mintLiqETH(address(this), 10 ether, 80 ether, 10 ether, block.timestamp);
        (, uint256 _shares) = mint(cuh, 1 ether, 1 ether, 100, block.timestamp);

        uint256 liquidity = lendgine.convertShareToLiquidity(_shares);
        (uint256 p0, uint256 p1) = (pair.reserve0(), pair.reserve1());
        uint256 r0 = PRBMath.mulDiv(p0, liquidity, pair.totalSupply());
        uint256 r1 = PRBMath.mulDiv(p1, liquidity, pair.totalSupply());

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), _shares);

        base.mint(address(pair), 1 ether);
        vm.prank(cuh);
        bytes[] memory data = new bytes[](4);

        data[0] = abi.encodeWithSelector(
            LendgineRouter.skim.selector,
            LendgineRouter.SkimParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                recipient: address(cuh)
            })
        );
        data[1] = abi.encodeWithSelector(
            LendgineRouter.burn.selector,
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                amount0Max: r0,
                amount1Max: r1,
                shares: _shares,
                recipient: address(lendgineRouter),
                deadline: block.timestamp
            })
        );
        data[2] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, 10, cuh);
        data[3] = abi.encodeWithSelector(Payment.refundETH.selector);

        lendgineRouter.multicall(data);

        assertEq(lendgine.balanceOf(cuh), 0);
        assertEq(pair.buffer(), 0);
        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(address(lendgineRouter).balance, 0);
    }

    function testBurnBasic() public {
        mintLiqETH(address(this), 10 ether, 80 ether, 10 ether, block.timestamp);
        (, uint256 _shares) = mint(cuh, 1 ether, 1 ether, 100, block.timestamp);

        vm.prank(cuh);
        lendgineRouter.refundETH();

        uint256 liquidity = lendgine.convertShareToLiquidity(_shares);
        (uint256 p0, uint256 p1) = (pair.reserve0(), pair.reserve1());
        uint256 r0 = PRBMath.mulDiv(p0, liquidity, pair.totalSupply());
        uint256 r1 = PRBMath.mulDiv(p1, liquidity, pair.totalSupply());

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), _shares);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(
            LendgineRouter.burn.selector,
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                amount0Max: r0,
                amount1Max: r1,
                shares: _shares,
                recipient: address(lendgineRouter),
                deadline: block.timestamp
            })
        );

        data[1] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, 0, cuh);
        vm.prank(cuh);
        lendgineRouter.multicall(data);

        // assertEq(address(lendgine), _lendgine);
        // assertEq(lendgine.balanceOf(cuh), 0);

        // assertEq(pair.totalSupply(), 10 ether);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(address(lendgineRouter).balance, 0);
    }
}
