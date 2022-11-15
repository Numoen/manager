pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";

import { IUniswapV2Factory } from "../src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { NumoenLibrary } from "../src/libraries/NumoenLibrary.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import "forge-std/console2.sol";

contract LendgineRouterTest is TestHelper {
    IUniswapV2Factory public uniFactory = IUniswapV2Factory(0x62d5b84bE28a183aBB507E125B384122D2C25fAE);
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
        console2.log(borrowAmount);
        speculative.mint(spender, amount);

        vm.prank(spender);
        speculative.approve(address(lendgineRouter), amount);

        vm.prank(spender);
        (_lendgine, _shares) = lendgineRouter.mint(
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

    function setUp() public {
        _setUp();

        lendgineRouter = new LendgineRouter(address(factory), address(uniFactory));

        address _uniPair = uniFactory.createPair(address(base), address(speculative));
        uniPair = IUniswapV2Pair(_uniPair);
        base.mint(_uniPair, 10000 ether);
        speculative.mint(_uniPair, 10000 ether);
        uniPair.mint(address(this));
    }

    function testMintBasic() public {
        mintLiq(address(this), 100 ether, 800 ether, 100 ether, block.timestamp);
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
        mintLiq(address(this), 10 ether, 80 ether, 10 ether, block.timestamp);
        (, uint256 _shares) = mint(cuh, 1 ether, 1 ether, 100, block.timestamp);

        uint256 liquidity = lendgine.convertShareToLiquidity(_shares);

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), _shares);

        base.mint(address(pair), 1 ether);
        vm.prank(cuh);
        address _lendgine = lendgineRouter.burn(
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                liquidityMax: liquidity,
                shares: _shares,
                recipient: cuh,
                deadline: block.timestamp
            })
        );
    }

    function testBurnBasic() public {
        mintLiq(address(this), 10 ether, 80 ether, 10 ether, block.timestamp);
        (, uint256 _shares) = mint(cuh, 1 ether, 1 ether, 100, block.timestamp);

        uint256 liquidity = lendgine.convertShareToLiquidity(_shares);

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), _shares);

        vm.prank(cuh);
        address _lendgine = lendgineRouter.burn(
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                liquidityMax: liquidity,
                shares: _shares,
                recipient: cuh,
                deadline: block.timestamp
            })
        );

        // assertEq(_amountS, 1 ether);
        // assertEq(_amountB, 8 ether);

        assertEq(address(lendgine), _lendgine);
        // assertEq(lendgine.balanceOf(cuh), 0);

        // assertEq(pair.totalSupply(), 10 ether);
        assertEq(pair.buffer(), 0);

        // assertEq(base.balanceOf(address(lendgineRouter)), 0);
        // assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
    }
}
