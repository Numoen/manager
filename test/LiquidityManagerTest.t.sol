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

    Factory public factory = Factory(0x60BA0a7DCd2caa3Eb171f0A8692A37d34900E247);
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
                amount0Min: amount0,
                amount1Min: amount1,
                liquidity: liquidity,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function assertPosition(
        uint256 tokenID,
        address operator,
        LendgineAddress.LendgineKey memory key,
        uint256 liquidity,
        uint256 rewardPerLiquidityPaid,
        uint256 tokensOwed
    ) public {
        {
            (
                ,
                address _base,
                address _speculative,
                uint256 _baseScaleFactor,
                uint256 _speculativeScaleFactor,
                uint256 _upperBound,
                ,
                ,

            ) = liquidityManager.getPosition(tokenID);
            assertEq(key.base, _base);
            assertEq(key.speculative, _speculative);
            assertEq(key.baseScaleFactor, _baseScaleFactor);
            assertEq(key.speculativeScaleFactor, _speculativeScaleFactor);
            assertEq(key.upperBound, _upperBound);
        }
        {
            (
                address _operator,
                ,
                ,
                ,
                ,
                ,
                uint256 _liquidity,
                uint256 _rewardPerLiquidityPaid,
                uint256 _tokensOwed
            ) = liquidityManager.getPosition(tokenID);

            assertEq(operator, _operator);
            assertEq(liquidity, _liquidity);
            assertEq(rewardPerLiquidityPaid, _rewardPerLiquidityPaid);
            assertEq(tokensOwed, _tokensOwed);
        }
    }

    constructor() {
        base = new MockERC20();
        speculative = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");

        key = LendgineAddress.getLendgineKey(address(base), address(speculative), 18, 18, upperBound);
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

        liquidityManager = new LiquidityManager(address(factory));
    }

    function testMintBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        assertEq(tokenID, 1);

        assertPosition(tokenID, cuh, key, 1 ether, 0, 0);
    }

    function testIncreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

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
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp
            })
        );

        assertPosition(tokenID, cuh, key, 2 ether, 0, 0);
    }

    function testIncreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

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
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp + 365 days
            })
        );

        assertPosition(tokenID, cuh, key, 2 ether, dilutionLP * 10, dilutionLP * 10);
    }

    function testDecreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        vm.prank(cuh);
        liquidityManager.decreaseLiquidity(
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                liquidity: 1 ether,
                recipient: cuh,
                deadline: block.timestamp
            })
        );

        (
            address _operator,
            address _base,
            address _speculative,
            ,
            ,
            uint256 _upperBound,
            uint256 _liquidity,
            uint256 _rewardPerLiquidityPaid,
            uint256 _tokensOwed
        ) = liquidityManager.getPosition(tokenID);

        assertEq(_operator, cuh);
        assertEq(address(base), _base);
        assertEq(address(speculative), _speculative);
        assertEq(upperBound, _upperBound);
        assertEq(_liquidity, 0);
        assertEq(_rewardPerLiquidityPaid, 0);
        assertEq(_tokensOwed, 0);
    }

    function testDecreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        liquidityManager.decreaseLiquidity(
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                liquidity: 1_000_000,
                recipient: cuh,
                deadline: block.timestamp + 365 days
            })
        );

        assertPosition(tokenID, cuh, key, 1 ether - 1_000_000, dilutionLP * 10, dilutionLP * 10);
    }

    function testCollectBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        liquidityManager.collect(
            LiquidityManager.CollectParams({ tokenID: tokenID, recipient: cuh, amountRequested: dilutionLP * 10 })
        );

        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(cuh), dilutionLP * 10);

        assertPosition(tokenID, cuh, key, 1 ether, dilutionLP * 10, 0);
    }

    function testOverCollect() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);
        assertPosition(tokenID, cuh, key, 1 ether, 0, 0);

        vm.prank(cuh);
        uint256 amountCollected = liquidityManager.collect(
            LiquidityManager.CollectParams({ tokenID: tokenID, recipient: cuh, amountRequested: 10 })
        );
        assertEq(amountCollected, 0);
    }

    function testIncreaseUninitialized() public {
        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 8 ether);

        vm.prank(cuh);
        vm.expectRevert(LiquidityManager.UnauthorizedError.selector);
        liquidityManager.increaseLiquidity(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: 2,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp + 365 days
            })
        );
    }

    function testStaggerDepositSameOwner() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);
        mint(address(this), 5 ether);
        pair.burn(address(dennis), 0.5 ether);
        vm.warp(block.timestamp + 365 days);

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
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp + 365 days
            })
        );
        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;
        uint256 dilutionLP2 = ((0.5 ether - dilutionLP) * lendgine.getBorrowRate(0.5 ether - dilutionLP, 2 ether)) /
            1 ether;

        vm.prank(cuh);
        uint256 amountCollected = liquidityManager.collect(
            LiquidityManager.CollectParams({
                tokenID: tokenID,
                recipient: cuh,
                amountRequested: dilutionLP * 10 + dilutionLP2 * 10
            })
        );

        assertEq(lendgine.totalLiquidity(), 2 ether);
        assertPosition(tokenID, cuh, key, 2 ether, dilutionLP * 10 + dilutionLP2 * 5, 0);
        assertEq(lendgine.rewardPerLiquidityStored(), dilutionLP * 10 + dilutionLP2 * 5);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(amountCollected, dilutionLP * 10 + dilutionLP2 * 10);

        uint256 collateral = lendgine.convertLiquidityToAsset(lendgine.convertShareToLiquidity(0.5 ether));
        assertEq(speculative.balanceOf(address(lendgine)), collateral);
    }

    function testStaggerDepositDifferentOwner() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);
        mint(address(this), 5 ether);
        pair.burn(address(this), 0.5 ether);
        vm.warp(block.timestamp + 365 days);

        uint256 tokenID2 = mintLiq(dennis, 1 ether, 8 ether, 1 ether, block.timestamp + 365 days);

        assertFalse(tokenID == tokenID2);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;
        uint256 dilutionLP2 = ((0.5 ether - dilutionLP) * lendgine.getBorrowRate(0.5 ether - dilutionLP, 2 ether)) /
            1 ether;

        assertEq(lendgine.totalLiquidity(), 2 ether);
        assertPosition(tokenID, cuh, key, 1 ether, 0, 0);
        assertPosition(tokenID2, dennis, key, 1 ether, dilutionLP * 10, 0);

        vm.prank(cuh);
        uint256 amountCollected = liquidityManager.collect(
            LiquidityManager.CollectParams({
                tokenID: tokenID,
                recipient: cuh,
                amountRequested: dilutionLP * 10 + dilutionLP2 * 5
            })
        );

        assertPosition(tokenID, cuh, key, 1 ether, dilutionLP * 10 + dilutionLP2 * 5, 0);
        assertEq(amountCollected, dilutionLP * 10 + dilutionLP2 * 5);

        vm.prank(dennis);
        amountCollected = liquidityManager.collect(
            LiquidityManager.CollectParams({ tokenID: tokenID2, recipient: dennis, amountRequested: dilutionLP2 * 5 })
        );
        assertPosition(tokenID2, dennis, key, 1 ether, dilutionLP * 10 + dilutionLP2 * 5, 0);
        assertEq(amountCollected, dilutionLP2 * 5);
    }

    function testDonateDDos() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(liquidityManager), 8 ether);

        base.mint(address(pair), 1 ether);

        vm.prank(cuh);
        liquidityManager.increaseLiquidity(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp
            })
        );

        console2.log(tokenID);
        assertPosition(tokenID, cuh, key, 2 ether, 0, 0);
        // assertEq(base.balanceOf(cuh), 1 ether);
    }
}
