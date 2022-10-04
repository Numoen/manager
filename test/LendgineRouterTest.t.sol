pragma solidity ^0.8.4;

import { LendgineRouter } from "../src/LendgineRouter.sol";
import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

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

    Factory public factory;
    Lendgine public lendgine;
    Pair public pair;

    LendgineAddress.LendgineKey public key;
    uint256 public k;

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

        key = LendgineAddress.getLendgineKey(address(base), address(speculative), upperBound);
    }

    function mint(
        address spender,
        uint256 amount,
        uint256 deadline
    )
        public
        returns (
            address _lendgine,
            uint256 _shares,
            uint256 _amountB
        )
    {
        speculative.mint(spender, amount);

        vm.prank(spender);
        speculative.approve(address(lendgineRouter), amount);

        vm.prank(spender);
        (_lendgine, _shares, _amountB) = lendgineRouter.mint(
            LendgineRouter.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                amountS: amount,
                sharesMin: 0,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function mintLiq(
        address spender,
        uint256 amount0,
        uint256 amount1,
        uint24 tick,
        uint256 deadline
    ) public returns (uint256 tokenID, uint256 liquidity) {
        base.mint(spender, amount0);
        speculative.mint(spender, amount1);

        vm.prank(spender);
        base.approve(address(liquidityManager), amount0);

        vm.prank(spender);
        speculative.approve(address(liquidityManager), amount1);

        vm.prank(spender);
        (tokenID, liquidity) = liquidityManager.mint(
            LiquidityManager.MintParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                tick: tick,
                amount0: amount0,
                amount1: amount1,
                liquidityMin: k,
                recipient: spender,
                deadline: deadline
            })
        );
    }

    function setUp() public {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(base), address(speculative), upperBound);
        lendgine = Lendgine(_lendgine);

        address _pair = lendgine.pair();
        pair = Pair(_pair);

        k = pair.calcInvariant(1 ether, 1 ether);

        lendgineRouter = new LendgineRouter(address(factory));
        liquidityManager = new LiquidityManager(address(factory));
    }

    function testMintBasic() public {
        mintLiq(address(this), 1 ether, 1 ether, 1, 2);
        (address _lendgine, uint256 _shares, uint256 _amountB) = mint(cuh, 1 ether, 2);

        uint256 baseTokens = _shares / 1 ether;
        assertEq(base.balanceOf(cuh), baseTokens);
        assertEq(base.balanceOf(cuh), _amountB);

        assertEq(lendgine.balanceOf(cuh), 10**35);
        assertEq(address(lendgine), _lendgine);
        assertEq(_shares, 10**35);

        assertEq(pair.totalSupply(), k - 10**35);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
    }

    function testBurnBasic() public {
        mintLiq(address(this), 1 ether, 1 ether, 1, 2);
        mint(cuh, 1 ether, 2);

        base.mint(cuh, 1 ether);

        vm.prank(cuh);
        base.approve(address(lendgineRouter), 1 ether);

        vm.prank(cuh);
        lendgine.approve(address(lendgineRouter), 10**35);

        vm.prank(cuh);
        (address _lendgine, uint256 _amountS, uint256 _amountB) = lendgineRouter.burn(
            LendgineRouter.BurnParams({
                base: address(base),
                speculative: address(speculative),
                upperBound: upperBound,
                shares: 10**35,
                amountSMin: 0,
                amountBMax: 1 ether,
                recipient: cuh,
                deadline: 2
            })
        );

        assertEq(speculative.balanceOf(cuh), _amountS);
        assertEq(_amountS, 1 ether);
        assertEq(_amountB, 0.1 ether);

        assertEq(address(lendgine), _lendgine);
        assertEq(lendgine.balanceOf(cuh), 0);

        assertEq(pair.totalSupply(), k);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(address(lendgineRouter)), 0);
        assertEq(speculative.balanceOf(address(lendgineRouter)), 0);
    }
}
