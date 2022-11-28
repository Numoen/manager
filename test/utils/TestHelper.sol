pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { CallbackHelper } from "./CallbackHelper.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";

import { LiquidityManager } from "../../src/LiquidityManager.sol";
import { LendgineAddress } from "../../src/libraries/LendgineAddress.sol";
import { IWETH9 } from "../../src/interfaces/IWETH9.sol";
import "forge-std/console2.sol";

abstract contract TestHelper is Test, CallbackHelper {
    MockERC20 public immutable base;
    MockERC20 public speculative;

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

    constructor() {
        speculative = new MockERC20();
        base = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");
    }

    function _setUp() public {
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

    struct MathParams {
        uint256 speculativeAmount;
        uint256 upperBound;
        uint256 price;
        uint256 slippageBps;
    }

    function determineBorrowAmount(MathParams memory params) internal pure returns (uint256) {
        uint256 x0 = PRBMathUD60x18.powu(params.price, 2);
        uint256 x1 = (params.upperBound - params.price) * 2;

        uint256 numerator = PRBMathUD60x18.mul(x1, params.speculativeAmount) +
            ((10000 - params.slippageBps) *
                PRBMathUD60x18.div(PRBMathUD60x18.mul(x0, params.speculativeAmount), params.price)) /
            10000;
        uint256 denominator = 2 *
            params.upperBound -
            (((10000 - params.slippageBps) * PRBMathUD60x18.div(x0, params.price)) / 10000) -
            x1;

        return PRBMathUD60x18.div(numerator, denominator);
    }
}