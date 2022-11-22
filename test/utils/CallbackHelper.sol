pragma solidity ^0.8.4;

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";

import { LendgineAddress } from "../../src/libraries/LendgineAddress.sol";
import { SafeTransferLib } from "../../src/libraries/SafeTransferLib.sol";
import { ERC20 } from "numoen-core/ERC20.sol";
import { Payment } from "../../src/Payment.sol";
import "forge-std/console2.sol";

abstract contract CallbackHelper is IMintCallback, Payment {
    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    constructor() Payment(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6) {}

    function MintCallback(uint256 amount, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        // CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount > 0) pay(decoded.key.speculative, decoded.payer, msg.sender, amount);
    }
}
