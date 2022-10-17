pragma solidity ^0.8.4;

import { Lendgine } from "numoen-core/Lendgine.sol";
import { Factory } from "numoen-core/Factory.sol";

import { LendgineAddress } from "./LendgineAddress.sol";

library CallbackValidation {
    error VerifyError();

    function verifyCallback(address factory, LendgineAddress.LendgineKey memory lendgineKey) internal view {
        address lendgine = Factory(factory).getLendgine(
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        if (msg.sender != lendgine) revert VerifyError();
    }

    function verifyPairCallback(address factory, LendgineAddress.LendgineKey memory lendgineKey) internal view {
        address lendgine = Factory(factory).getLendgine(
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        address pair = Lendgine(lendgine).pair();
        if (msg.sender != pair) revert VerifyError();
    }
}
