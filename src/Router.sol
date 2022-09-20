// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "v2-core/interfaces/IUniswapV2Factory.sol";

import { NumoenLibrary } from "./libraries/NumoenLibrary.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { UniswapV2Library } from "v2-periphery";

contract Router is IMintCallback {
    address private immutable factory;
    address private immutable uniFactory;

    constructor(address _factory, address _uniFactory) {
        factory = _factory;
        uniFactory = _uniFactory;
    }

    struct MintCallbackData {
        LendgineAddress.LendgineKey key;
        uint256 userAmount;
        address user;
    }

    function MintCallback(uint256 amount, bytes calldata data) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        // withdraw lp
        address pair = Lendgine(msg.sender).pair();
        SafeTransferLib.safeTransfer(ERC20(pair), pair, Pair(pair).balanceOf(address(this)));
        Pair(pair).burn(address(this));

        // swap for speculative
        // (uint256 reserveIn, uint256 reserveOut) = 

        address uniPair = IUniswapV2Factory(uniFactory).getPair(decoded.key.token0, decoded.key.token1);
        bool zeroForOne = decoded.key.token0 < decoded.key.token1;
        SafeTransferLib.safeTransfer(
            ERC20(decoded.key.token0),
            uniPair,
            ERC20(decoded.key.token0).balanceOf(address(this))
        );
        IUniswapV2Pair(uniPair).swap()

        // transfer the user funds to the lendgine
        SafeTransferLib.safeTransferFrom(ERC20(decoded.key.token0), decoded.user, msg.sender, decoded.userAmount);
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
        (uint256 pairBalance0, uint256 pairBalance1) = Pair(pair).balances();
        uint256 pairTotalSupply = Pair(pair).totalSupply();

        uint256 amountSpec = (1 ether * pairBalance0) / pairTotalSupply;
        uint256 amountBase = (1 ether * pairBalance1) / pairTotalSupply;

        uint256 valueLP = NumoenLibrary.getAmountOut(amountBase, false, pairBalance0, pairBalance1) + amountSpec;

        uint256 denom = ((NumoenLibrary.getMinCollateralRatio(upperBound) * 1 ether) / valueLP) - 1 ether;

        uint256 borrowAmount = (amount * 1 ether) / denom;

        LendgineAddress.LendgineKey memory key = LendgineAddress.getLendgineKey(
            address(speculative),
            address(base),
            upperBound
        );

        Lendgine(lendgine).mint(
            address(this),
            borrowAmount + amount,
            abi.encode(MintCallbackData({ key: key, userAmount: amount, user: msg.sender }))
        );
    }
}
