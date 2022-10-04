pragma solidity ^0.8.4;

import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";

library CallbackValidation {
    error VerifyError();

    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view {
        verifyCallback(factory, LendgineAddress.getLendgineKey(tokenA, tokenB, fee));
    }

    function verifyCallback(address factory, LendgineAddress.LendgineKey memory lendgineKey) internal view {
        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        if (msg.sender != lendgine) revert VerifyError();
    }

    function verifyPairCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view {
        verifyCallback(factory, LendgineAddress.getLendgineKey(tokenA, tokenB, fee));
    }

    function verifyPairCallback(address factory, LendgineAddress.LendgineKey memory lendgineKey) internal view {
        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        address pair = Lendgine(lendgine).pair();
        if (msg.sender != pair) revert VerifyError();
    }
}
