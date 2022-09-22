// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { ILPCallback } from "numoen-core/interfaces/ILPCallback.sol";
import { IPairMintCallback } from "numoen-core/interfaces/IPairMintCallback.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

import { NumoenLibrary } from "./libraries/NumoenLibrary.sol";
import { UniswapV2Library } from "./libraries/UniswapV2Library.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console2.sol";

contract Router is IMintCallback, ILPCallback, IPairMintCallback {
    address private immutable factory;
    address private immutable uniFactory;

    uint256 public constant maxSlippageBps = 600;

    constructor(address _factory, address _uniFactory) {
        factory = _factory;
        uniFactory = _uniFactory;
    }

    struct MintCallbackData {
        LendgineAddress.LendgineKey key;
        uint256 userAmount;
        address user;
    }

    /// @param amount how many tokens are owed in total
    function MintCallback(uint256 amount, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        // withdraw lp
        address pair = Lendgine(msg.sender).pair();
        SafeTransferLib.safeTransfer(ERC20(pair), pair, Pair(pair).balanceOf(address(this)));
        Pair(pair).burn(address(this));

        // swap for speculative
        uint256 swapAmount = ERC20(decoded.key.token1).balanceOf(address(this));

        (uint256 reserveIn, uint256 reserveOut) = UniswapV2Library.getReserves(
            uniFactory,
            decoded.key.token1,
            decoded.key.token0
        );
        uint256 amountOut = UniswapV2Library.getAmountOut(swapAmount, reserveIn, reserveOut);

        address uniPair = IUniswapV2Factory(uniFactory).getPair(decoded.key.token0, decoded.key.token1);
        bool zeroForOne = decoded.key.token0 < decoded.key.token1;

        // swap and send output to lendgine
        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token1),
            uniPair,
            ERC20(decoded.key.token1).balanceOf(address(this))
        );
        IUniswapV2Pair(uniPair).swap(zeroForOne ? 0 : amountOut, zeroForOne ? amountOut : 0, msg.sender, new bytes(0));

        // transfer tokens from lp
        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token0),
            msg.sender,
            ERC20(decoded.key.token0).balanceOf(address(this))
        );

        uint256 fromLP = amountOut + ERC20(decoded.key.token0).balanceOf(address(this));

        uint256 userOwed = amount - fromLP;

        if (decoded.userAmount < userOwed) revert();

        // transfer the user funds to the lendgine
        SafeTransferLib.safeTransferFrom(ERC20(decoded.key.token0), decoded.user, msg.sender, userOwed);
    }

    /// @dev for now only can pay with speculative tokens
    function mint(
        uint256 amount,
        address speculative,
        address base,
        uint256 upperBound
    ) public {
        address lendgine = Factory(factory).getLendgine(speculative, base, upperBound);
        address pair = Lendgine(lendgine).pair();

        uint256 slippageAdjustedAmount = (amount * (10000 - maxSlippageBps)) / 10000;

        uint256 borrowAmount;
        {
            (uint256 pairBalance0, uint256 pairBalance1) = Pair(pair).balances();
            uint256 pairTotalSupply = Pair(pair).totalSupply();

            uint256 amountSpec = (1 ether * pairBalance0) / pairTotalSupply;
            uint256 amountBase = (1 ether * pairBalance1) / pairTotalSupply;

            uint256 valueLP = NumoenLibrary.getAmountOut(amountBase, false, pairBalance0, pairBalance1) + amountSpec;

            uint256 denom = ((NumoenLibrary.getMinCollateralRatio(upperBound) * 1 ether) / valueLP) - 1 ether;

            borrowAmount = (slippageAdjustedAmount * 1 ether) / denom;
        }

        LendgineAddress.LendgineKey memory key = LendgineAddress.getLendgineKey(
            address(speculative),
            address(base),
            upperBound
        );

        Lendgine(lendgine).mint(
            address(this),
            (borrowAmount + slippageAdjustedAmount),
            abi.encode(MintCallbackData({ key: key, userAmount: amount, user: msg.sender }))
        );

        Lendgine(lendgine).transfer(msg.sender, Lendgine(lendgine).balanceOf(address(this)));
    }

    struct LPCallbackData {
        LendgineAddress.LendgineKey key;
        address user;
    }

    function LPCallback(uint256 amountLP, bytes calldata data) external override {
        LPCallbackData memory decoded = abi.decode(data, (LPCallbackData));
        address pair = Lendgine(msg.sender).pair();
        address uniPair = IUniswapV2Factory(uniFactory).getPair(decoded.key.token0, decoded.key.token1);

        // figure out what we need to get amountLP
        uint256 amountSpec;
        uint256 amountBase;
        {
            (uint256 pairBalance0, uint256 pairBalance1) = Pair(pair).balances();
            uint256 pairTotalSupply = Pair(pair).totalSupply();

            amountSpec = (amountLP * pairBalance0) / pairTotalSupply;
            amountBase = (amountLP * pairBalance1) / pairTotalSupply;
        }
        // swap
        (uint256 reserveIn, uint256 reserveOut) = UniswapV2Library.getReserves(
            uniFactory,
            decoded.key.token1,
            decoded.key.token0
        );
        uint256 amountIn = UniswapV2Library.getAmountIn(amountBase, reserveIn, reserveOut);
        bool zeroForOne = decoded.key.token0 < decoded.key.token1;

        SafeTransferLib.safeTransfer(ERC20(zeroForOne ? decoded.key.token0 : decoded.key.token1), uniPair, amountIn);

        IUniswapV2Pair(uniPair).swap(
            zeroForOne ? 0 : amountBase,
            zeroForOne ? amountBase : 0,
            address(this),
            new bytes(0)
        );

        // deposit LP
        Pair(pair).mint(amountSpec, amountBase, msg.sender, abi.encode(PairMintCallbackData({ key: decoded.key })));

        // send remaining speculative to user
        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token0),
            decoded.user,
            ERC20(decoded.key.token0).balanceOf(address(this))
        );
    }

    struct PairMintCallbackData {
        LendgineAddress.LendgineKey key;
    }

    function PairMintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        PairMintCallbackData memory decoded = abi.decode(data, (PairMintCallbackData));

        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token0 < decoded.key.token1 ? decoded.key.token0 : decoded.key.token1),
            msg.sender,
            amount0
        );

        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token0 < decoded.key.token1 ? decoded.key.token1 : decoded.key.token0),
            msg.sender,
            amount1
        );
    }

    function burn(
        uint256 amount,
        address speculative,
        address base,
        uint256 upperBound
    ) public {
        address lendgine = Factory(factory).getLendgine(speculative, base, upperBound);
        // address pair = Lendgine(lendgine).pair();

        LendgineAddress.LendgineKey memory key = LendgineAddress.getLendgineKey(
            address(speculative),
            address(base),
            upperBound
        );

        SafeTransferLib.safeTransferFrom(ERC20(lendgine), msg.sender, lendgine, amount);

        Lendgine(lendgine).burn(address(this), abi.encode(LPCallbackData({ key: key, user: msg.sender })));
    }
}
