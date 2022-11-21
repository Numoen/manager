pragma solidity ^0.8.4;

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";

import { LendgineAddress } from "../../src/libraries/LendgineAddress.sol";
import { SafeTransferLib } from "../../src/libraries/SafeTransferLib.sol";
import { ERC20 } from "numoen-core/ERC20.sol";
import "forge-std/console2.sol";

abstract contract CallbackHelper is IMintCallback {
    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    function MintCallback(uint256 amount, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        // CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (decoded.payer == address(this)) {
            if (amount > 0) SafeTransferLib.safeTransfer(decoded.key.speculative, msg.sender, amount);
        } else {
            if (amount > 0)
                SafeTransferLib.safeTransferFrom(decoded.key.speculative, decoded.payer, msg.sender, amount);
        }
    }
}
