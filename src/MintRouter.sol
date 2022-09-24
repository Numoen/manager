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

contract MintRouter is ILPCallback, IPairMintCallback {
    address private immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    function LPCallback(uint256 amountLP, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));

        address pair = Lendgine(msg.sender).pair();

        if (amountLP > 0) pay(ERC20(pair), decoded.payer, msg.sender, amountLP);
    }

    function PairMintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));

        if (amount0 > 0) pay(ERC20(decoded.key.token0), decoded.payer, msg.sender, amount0);
        if (amount1 > 0) pay(ERC20(decoded.key.token1), decoded.payer, msg.sender, amount1);
    }

    function mintMaker(
        uint256 amountSpec,
        uint256 amountBase,
        address speculative,
        address base,
        uint256 upperBound
    ) external {
        address lendgine = Factory(factory).getLendgine(speculative, base, upperBound);
        address pair = Lendgine(lendgine).pair();

        LendgineAddress.LendgineKey memory key = LendgineAddress.getLendgineKey(
            address(speculative),
            address(base),
            upperBound
        );

        uint256 liquidity = Pair(pair).mint(
            amountSpec,
            amountBase,
            address(this),
            abi.encode(CallbackData({ key: key, payer: msg.sender }))
        );

        Lendgine(lendgine).mintMaker(
            msg.sender,
            liquidity,
            abi.encode(CallbackData({ key: key, payer: address(this) }))
        );
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param recipient The entity that will receive payment
    /// @param value The amount to pay
    function pay(
        ERC20 token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        // if (token == WETH9 && address(this).balance >= value) {
        //     // pay with WETH9
        //     IWETH9(WETH9).deposit{ value: value }(); // wrap only what is needed to pay
        //     IWETH9(WETH9).transfer(recipient, value);
        // } else
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            SafeTransferLib.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            SafeTransferLib.safeTransferFrom(token, payer, recipient, value);
        }
    }
}
