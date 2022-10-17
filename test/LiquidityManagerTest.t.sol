pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract LiquidityManagerTest is Test, CallbackHelper {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory;
    Lendgine public lendgine;
    Pair public pair;

    LendgineAddress.LendgineKey public key;

    LiquidityManager public liquidityManager;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    function mint(address spender, uint256 amount) public {
        speculative.mint(spender, amount);

        lendgine.mint(spender, amount, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));
    }

    function mintLiq(
        address spender,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        uint16 tick,
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
                upperBound: upperBound,
                tick: tick,
                amount0: amount0,
                amount1: amount1,
                liquidity: liquidity,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    constructor() {
        base = new MockERC20();
        speculative = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");

        key = LendgineAddress.getLendgineKey(address(base), address(speculative), upperBound);
    }

    function setUp() public {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(base), address(speculative), upperBound);
        lendgine = Lendgine(_lendgine);

        address _pair = lendgine.pair();
        pair = Pair(_pair);

        liquidityManager = new LiquidityManager(address(factory));
    }

    function testMintBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(tokenID, 1);
        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 1 ether);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    // test double mint

    function testIncreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 8 ether);

        vm.prank(cuh);
        liquidityManager.increaseLiquidity(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1 ether,
                amount1: 8 ether,
                liquidity: 1 ether,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 2 ether);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    function testIncreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        mint(address(this), 1 ether);

        vm.warp(1 days + 1);

        uint256 dilution = 0.1 ether / 10000;

        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 8 ether);

        vm.prank(cuh);
        liquidityManager.increaseLiquidity(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1 ether,
                amount1: 8 ether,
                liquidity: 1 ether,
                deadline: 1 days + 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 2 ether);
        assertEq(_rewardPerLiquidityPaid, (dilution * 10));
        assertEq(_tokensOwed, (dilution * 10));
    }

    function testDecreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        vm.prank(cuh);
        liquidityManager.decreaseLiquidity(
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1 ether,
                amount1: 8 ether,
                liquidity: 1 ether,
                recipient: cuh,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 0);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    function testDecreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        mint(address(this), 1 ether);

        vm.warp(1 days + 1);

        uint256 dilution = 0.1 ether / 10000;

        vm.prank(cuh);
        liquidityManager.decreaseLiquidity(
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1_000_000,
                amount1: 8_000_000,
                liquidity: 1_000_000,
                recipient: cuh,
                deadline: 1 days + 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 1 ether - 1_000_000);
        assertEq(_rewardPerLiquidityPaid, (dilution * 10));
        assertEq(_tokensOwed, (dilution * 10));
    }

    function testCollectBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, 1, 2);

        mint(address(this), 1 ether);

        vm.warp(1 days + 1);

        uint256 dilution = 0.1 ether / 10000;

        vm.prank(cuh);
        liquidityManager.collect(
            LiquidityManager.CollectParams({ tokenID: tokenID, recipient: cuh, amountRequested: (dilution * 10) })
        );

        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(cuh), (dilution * 10));

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint16 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, 1 ether);
        assertEq(_rewardPerLiquidityPaid, (dilution * 10));
        assertEq(_tokensOwed, 0);
    }

    // test double collect
}
