// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "numoen-core/Lendgine.sol";
import { Factory } from "numoen-core/Factory.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

library CallbackValidation {
    error VerifyError();

    function verifyCallback(address factory, LendgineAddress.LendgineKey memory lendgineKey) internal view {
        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );
        if (msg.sender != lendgine) revert VerifyError();
    }
}
