pragma solidity ^0.8.4;

import { LiquidityManager } from "../src/LiquidityManager.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { NumoenLibrary } from "../src/libraries/NumoenLibrary.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { MockERC20 } from "./utils/mocks/MockERC20.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract NumoenLibraryTest is Test {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory = Factory(0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC);
    Lendgine public lendgine;
    Pair public pair;

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

    function testPriceToReserves1() public {
        uint256 liquidity = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(1 ether, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        assertEq(r0, 1 ether);
        assertEq(r1, 8 ether);

        uint256 price = NumoenLibrary.reservesToPrice(r1, liquidity, upperBound);
        assertEq(price, 1 ether);
    }

    function testPriceToReservesScale() public {
        uint256 liquidity = 10**9;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(1 ether, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        assertEq(r0, 10**9);
        assertEq(r1, 8 * 10**9);

        uint256 price = NumoenLibrary.reservesToPrice(r1, liquidity, upperBound);
        assertEq(price, 1 ether);
    }

    function testPriceToReservesScaleUp() public {
        uint256 liquidity = 100 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(1 ether, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        assertEq(r0, 100 ether);
        assertEq(r1, 800 ether);

        uint256 price = NumoenLibrary.reservesToPrice(r1, liquidity, upperBound);
        assertEq(price, 1 ether);
    }

    function testBaseIn() public {
        uint256 liquidity = 1 ether;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSOut = 0.1 ether;
        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSOut, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 + amountBIn, r1 - amountSOut, liquidity));

        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSOut, r1 - amountSOut, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }

    function testBaseInScale() public {
        uint256 liquidity = 10**9;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSOut = 10**9;
        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSOut, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 + amountBIn, r1 - amountSOut, liquidity));

        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSOut, r1 - amountSOut, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }

    function testBaseInScaleUp() public {
        uint256 liquidity = 100 ether;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSOut = 10**9;
        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSOut, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 + amountBIn, r1 - amountSOut, liquidity));

        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSOut, r1 - amountSOut, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }

    function testBaseOut() public {
        uint256 liquidity = 1 ether;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSIn = 0.1 ether;
        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSIn, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 - amountBOut, r1 + amountSIn, liquidity));

        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSIn, r1 + amountSIn, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }

    function testBaseOutScale() public {
        uint256 liquidity = 10**9;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSIn = 10**9;
        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSIn, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 - amountBOut, r1 + amountSIn, liquidity));

        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSIn, r1 + amountSIn, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }

    function testBaseOutScaleUp() public {
        uint256 liquidity = 100 ether;
        uint256 price = 1 ether;
        (uint256 r0, uint256 r1) = NumoenLibrary.priceToReserves(price, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0, r1, liquidity));

        uint256 amountSIn = 1 ether;
        uint256 amountBOut = NumoenLibrary.getBaseOut(amountSIn, r1, liquidity, upperBound);
        assertTrue(pair.verifyInvariant(r0 - amountBOut, r1 + amountSIn, liquidity));

        uint256 amountBIn = NumoenLibrary.getBaseIn(amountSIn, r1 + amountSIn, liquidity, upperBound);
        assertEq(amountBIn, amountBOut);
    }
}
