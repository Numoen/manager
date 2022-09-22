pragma solidity ^0.8.4;

import { Router } from "../../src/Router.sol";

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";

import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

import { CallbackHelper } from "./CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

abstract contract TestHelper is Test, CallbackHelper {
    MockERC20 public immutable speculative;
    MockERC20 public immutable base;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory;

    Lendgine public lendgine;

    Pair public pair;

    IUniswapV2Pair public uniPair;

    IUniswapV2Factory public uniFactory;

    Router public router;

    uint256 public ethFork;

    LendgineAddress.LendgineKey public key;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    constructor() {
        ethFork = vm.createFork(vm.envString("ETH_RPC_URL"));
        vm.selectFork(ethFork);

        speculative = new MockERC20();
        base = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");

        key = LendgineAddress.getLendgineKey(address(speculative), address(base), upperBound);
    }

    function _setUp() internal {
        address factoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

        uniFactory = IUniswapV2Factory(factoryAddress);

        address _uniPair = uniFactory.createPair(address(speculative), address(base));

        uniPair = IUniswapV2Pair(_uniPair);

        factory = new Factory();

        (address _lendgine, address _pair) = factory.createLendgine(address(speculative), address(base), upperBound);

        lendgine = Lendgine(_lendgine);

        pair = Pair(_pair);

        router = new Router(address(factory), address(uniFactory));
    }

    function _mintUni(
        uint256 amountSpec,
        uint256 amountBase,
        address spender
    ) public {
        speculative.mint(spender, amountSpec);
        base.mint(spender, amountBase);

        vm.prank(spender);
        speculative.transfer(address(uniPair), amountSpec);
        vm.prank(spender);
        base.transfer(address(uniPair), amountBase);

        uniPair.mint(spender);
    }

    function _mintMaker(
        uint256 amountSpeculative,
        uint256 amountBase,
        address spender
    ) internal {
        speculative.mint(spender, amountSpeculative);
        base.mint(spender, amountBase);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amountSpeculative);

            vm.prank(spender);
            base.approve(address(this), amountBase);
        }

        uint256 liquidity = pair.mint(
            amountSpeculative,
            amountBase,
            spender,
            abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender }))
        );

        if (spender != address(this)) {
            vm.prank(spender);
            pair.approve(address(this), liquidity);
        }

        lendgine.mintMaker(spender, liquidity, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));
    }

    function _mint(uint256 amount, address spender) public {
        speculative.mint(spender, amount);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amount);
        }

        lendgine.mint(spender, amount, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));
    }
}
