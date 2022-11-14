pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { IUniswapV2Factory } from "../src/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { NumoenLibrary } from "../src/libraries/NumoenLibrary.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract LiquidityManagerTest is Test {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory = Factory(0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC);
    IUniswapV2Factory public uniFactory = IUniswapV2Factory(0x62d5b84bE28a183aBB507E125B384122D2C25fAE);

    Lendgine public lendgine;
    Pair public pair;
    IUniswapV2Pair public uniPair;

    LiquidityManager public liquidityManager;
    LendgineRouter public lendgineRouter;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    constructor() {
        base = new MockERC20();
        speculative = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");
    }

    function mint(
        address spender,
        uint256 liquidity,
        uint256 price,
        uint256 slippageBps,
        uint256 deadline
    ) public returns (address _lendgine, uint256 _shares) {
        uint256 amount = Lendgine(lendgine).convertLiquidityToAsset(liquidity);
        uint256 shares = Lendgine(lendgine).convertLiquidityToShare(liquidity);

        uint256 borrowAmount = NumoenLibrary.determineBorrowAmount(
            NumoenLibrary.MathParams0({
                speculativeAmount: amount,
                upperBound: upperBound,
                price: price,
                slippageBps: slippageBps
            })
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
                price: price,
                slippageBps: slippageBps,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function mintLiq(
        address spender,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        uint256 deadline
    ) public returns (uint256 tokenID) {
        base.mint(spender, amount0);
        speculative.mint(spender, amount1);

        vm.prank(spender);
        base.approve(address(liquidityManager), amount0);

        vm.prank(spender);
        speculative.approve(address(liquidityManager), amount1);

        vm.prank(spender);
        (tokenID) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                amount0: amount0,
                amount1: amount1,
                liquidity: liquidity,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function setUp() public {
        (address _lendgine, address _pair) = factory.createLendgine(
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );
        lendgine = Lendgine(_lendgine);
        pair = Pair(_pair);

        lendgineRouter = new LendgineRouter(address(factory), address(uniFactory));
        liquidityManager = new LiquidityManager(address(factory));

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
                shares: _shares,
                liquidityMax: liquidity,
                price: 1 ether,
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
