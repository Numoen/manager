pragma solidity ^0.8.4;

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";

import { Lendgine } from "numoen-core/Lendgine.sol";

import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import "forge-std/console2.sol";

abstract contract CallbackHelper is IMintCallback {
    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    function MintCallback(uint256 amount, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        // CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount > 0) pay(ERC20(decoded.key.speculative), decoded.payer, msg.sender, amount);
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
