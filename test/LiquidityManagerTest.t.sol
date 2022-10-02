pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract LiquidityManagerTest is Test {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory;
    Lendgine public lendgine;
    Pair public pair;

    LendgineAddress.LendgineKey public key;
    uint256 public k;

    LiquidityManager public liquidityManager;

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

        key = LendgineAddress.getLendgineKey(address(base), address(speculative), upperBound);
    }

    function setUp() public {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(base), address(speculative), upperBound);
        lendgine = Lendgine(_lendgine);

        address _pair = lendgine.pair();
        pair = Pair(_pair);

        k = pair.calcInvariant(1 ether, 1 ether);

        liquidityManager = new LiquidityManager(address(factory));
    }

    function testMintBasic() public {
        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        (uint256 tokenID, uint256 liquidity) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                tick: 1,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMin: 0,
                recipient: cuh,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint24 _tick,
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
        assertEq(_liquidity, liquidity);
        assertEq(_liquidity, k);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    function testMintLiquidity() public {
        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        (uint256 tokenID, uint256 liquidity) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                tick: 1,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMin: k,
                recipient: cuh,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint24 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(_liquidity, liquidity);
        assertEq(_liquidity, k);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    // test double mint

    function testIncreaseBasic() public {
        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        (uint256 tokenID, uint256 liquidity) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                tick: 1,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMin: k,
                recipient: cuh,
                deadline: 2
            })
        );

        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        (liquidity) = liquidityManager.increaseLiquidity(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMin: k,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint24 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(k, liquidity);
        assertEq(_liquidity, 2 * k);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    function testDecreaseBasic() public {
        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        (uint256 tokenID, uint256 liquidity) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                tick: 1,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMin: k,
                recipient: cuh,
                deadline: 2
            })
        );

        vm.prank(cuh);
        (liquidity) = liquidityManager.decreaseLiquidity(
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                amount0: 1 ether,
                amount1: 1 ether,
                liquidityMax: k,
                recipient: cuh,
                deadline: 2
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            uint256 _upperBound,
            uint24 _tick,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(1, _tick);
        assertEq(k, liquidity);
        assertEq(_liquidity, 0);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }
}
