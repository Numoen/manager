pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Payment } from "../src/Payment.sol";
import { IWETH9 } from "../src/interfaces/IWETH9.sol";
import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract LiquidityManagerTest is Test, CallbackHelper {
    MockERC20 public immutable base;
    IWETH9 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory = Factory(0x8780898Cf5f3E3b20714b0AAEA198817b1cA481d);
    Lendgine public lendgine;
    Pair public pair;
    IWETH9 public weth = IWETH9(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    LendgineAddress.LendgineKey public key;

    LiquidityManager public liquidityManager;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    function mint(address spender, uint256 amount) public {
        vm.deal(address(this), amount);

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
        speculative = weth;

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

        liquidityManager = new LiquidityManager(address(factory), address(weth));
    }

    function testMintBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        assertEq(tokenID, 1);

        assertPosition(tokenID, cuh, key, 1 ether, 0, 0);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testIncreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        base.mint(cuh, 1 ether);
        vm.deal(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        liquidityManager.increaseLiquidity{ value: 8 ether }(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp
            })
        );

        assertPosition(tokenID, cuh, key, 2 ether, 0, 0);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testIncreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        base.mint(cuh, 1 ether);
        vm.deal(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.prank(cuh);
        liquidityManager.increaseLiquidity{ value: 8 ether }(
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp + 365 days
            })
        );

        assertPosition(tokenID, cuh, key, 2 ether, dilutionLP * 10, dilutionLP * 10);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testDecreaseBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSelector(
            LiquidityManager.decreaseLiquidity.selector,
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                liquidity: 1 ether,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                recipient: address(0),
                deadline: block.timestamp
            })
        );
        data[1] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, 8 ether, cuh);
        data[2] = abi.encodeWithSelector(Payment.sweepToken.selector, address(base), 1 ether, cuh);

        vm.prank(cuh);
        liquidityManager.multicall(data);

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

        assertEq(weth.balanceOf(cuh), 0);
        assertEq(cuh.balance, 8 ether);
        assertEq(base.balanceOf(cuh), 1 ether);

        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testDecreaseInterest() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSelector(
            LiquidityManager.decreaseLiquidity.selector,
            LiquidityManager.DecreaseLiquidityParams({
                tokenID: tokenID,
                liquidity: 1_000_000,
                amount0Min: 0,
                amount1Min: 8_000_000,
                recipient: address(0),
                deadline: block.timestamp + 365 days
            })
        );
        data[1] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, 8_000_000, cuh);
        data[2] = abi.encodeWithSelector(Payment.sweepToken.selector, address(base), 1_000_000, cuh);

        vm.prank(cuh);
        liquidityManager.multicall(data);

        assertPosition(tokenID, cuh, key, 1 ether - 1_000_000, dilutionLP * 10, dilutionLP * 10);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testCollectBasic() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        mint(address(this), 5 ether);

        vm.warp(block.timestamp + 365 days);

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(
            LiquidityManager.collect.selector,
            LiquidityManager.CollectParams({
                tokenID: tokenID,
                recipient: address(0),
                amountRequested: dilutionLP * 10
            })
        );
        data[1] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, dilutionLP * 10, cuh);

        vm.prank(cuh);
        liquidityManager.multicall(data);

        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(cuh.balance, dilutionLP * 10);

        assertPosition(tokenID, cuh, key, 1 ether, dilutionLP * 10, 0);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }

    function testDonateDDos() public {
        uint256 tokenID = mintLiq(cuh, 1 ether, 8 ether, 1 ether, block.timestamp);

        base.mint(cuh, 1 ether);
        vm.deal(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(liquidityManager), 1 ether);

        vm.deal(address(this), 1 ether);
        weth.deposit{ value: 1 ether }();
        weth.transfer(address(pair), 1 ether);

        bytes[] memory data = new bytes[](3);

        data[0] = abi.encodeWithSelector(
            LiquidityManager.skim.selector,
            LiquidityManager.SkimParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                recipient: address(0)
            })
        );
        data[1] = abi.encodeWithSelector(Payment.unwrapWETH9.selector, 1 ether, cuh);
        data[2] = abi.encodeWithSelector(
            LiquidityManager.increaseLiquidity.selector,
            LiquidityManager.IncreaseLiquidityParams({
                tokenID: tokenID,
                amount0Min: 1 ether,
                amount1Min: 8 ether,
                liquidity: 1 ether,
                deadline: block.timestamp
            })
        );
        vm.prank(cuh);
        liquidityManager.multicall{ value: 8 ether }(data);

        assertPosition(tokenID, cuh, key, 2 ether, 0, 0);
        assertEq(base.balanceOf(address(liquidityManager)), 0);
        assertEq(speculative.balanceOf(address(liquidityManager)), 0);
        assertEq(lendgine.balanceOf(address(liquidityManager)), 0);
        assertEq(address(liquidityManager).balance, 0);
    }
}
