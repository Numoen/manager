pragma solidity ^0.8.4;

import { ILPCallback } from "numoen-core/interfaces/ILPCallback.sol";
import { IPairMintCallback } from "numoen-core/interfaces/IPairMintCallback.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";

import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console2.sol";

abstract contract CallbackHelper is IPairMintCallback, ILPCallback {
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
