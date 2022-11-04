pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

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
    Lendgine public lendgine;
    Pair public pair;

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
        uint256 deadline
    ) public returns (address _lendgine, uint256 _shares) {
        uint256 amount = Lendgine(lendgine).convertLiquidityToAsset(liquidity);
        uint256 shares = Lendgine(lendgine).convertLiquidityToShare(liquidity);
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
                price: price,
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

        lendgineRouter = new LendgineRouter(address(factory));
        liquidityManager = new LiquidityManager(address(factory));
    }

    function testMintBasic() public {
        mintLiq(address(this), 100 ether, 800 ether, 100 ether, block.timestamp);
        (address _lendgine, uint256 _shares) = mint(cuh, 1 ether, 1 ether, block.timestamp);

        assertEq(base.balanceOf(cuh), 1 ether);

        assertEq(lendgine.balanceOf(cuh), 1 ether);
        assertEq(address(lendgine), _lendgine);
        assertEq(_shares, 1 ether);

        assertEq(pair.totalSupply(), 99 ether);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
    }

    function testBurnBasic() public {
        mintLiq(address(this), 10 ether, 80 ether, 10 ether, block.timestamp);
        mint(cuh, 1 ether, 1 ether, block.timestamp);

        base.mint(cuh, 1 ether);
        speculative.mint(cuh, 8 ether);

        vm.prank(cuh);
        base.approve(address(lendgineRouter), 1 ether);

        vm.prank(cuh);
        speculative.approve(address(lendgineRouter), 8 ether);

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), 1 ether);

        vm.prank(cuh);
        (address _lendgine, uint256 _amountS, uint256 _amountB) = lendgineRouter.burn(
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                baseScaleFactor: 18,
                speculativeScaleFactor: 18,
                upperBound: upperBound,
                shares: 1 ether,
                liquidityMax: 1 ether,
                price: 1 ether,
                recipient: cuh,
                deadline: block.timestamp
            })
        );

        assertEq(_amountS, 1 ether);
        assertEq(_amountB, 8 ether);

        assertEq(address(lendgine), _lendgine);
        assertEq(lendgine.balanceOf(cuh), 0);

        assertEq(pair.totalSupply(), 10 ether);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
    }
}
