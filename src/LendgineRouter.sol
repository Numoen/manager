// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { IPairMintCallback } from "numoen-core/interfaces/IPairMintCallback.sol";

import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import "forge-std/console2.sol";

/// @notice Facilitates mint and burning Numoen Positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LendgineRouter.sol)
contract LendgineRouter is IMintCallback, IPairMintCallback {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(
        address indexed recipient,
        address indexed lendgine,
        uint256 shares,
        uint256 speculativeAmount,
        uint256 baseAmount
    );

    event Burn(
        address indexed payer,
        address indexed lendgine,
        uint256 shares,
        uint256 speculativeAmount,
        uint256 baseAmount
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LivelinessError();

    error SlippageError();

    error UnauthorizedError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                           LIVELINESS MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier checkDeadline(uint256 deadline) {
        if (deadline < block.timestamp) revert LivelinessError();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _factory) {
        factory = _factory;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK LOGIC
    //////////////////////////////////////////////////////////////*/

    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    function MintCallback(uint256 amount0, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        // TODO: verify sender

        if (amount0 > 0) pay(ERC20(decoded.key.speculative), decoded.payer, msg.sender, amount0);
    }

    function PairMintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        if (decoded.payer == address(this)) revert UnauthorizedError();

        if (amount0 > 0) pay(ERC20(decoded.key.base), decoded.payer, msg.sender, amount0);
        if (amount1 > 0) pay(ERC20(decoded.key.speculative), decoded.payer, msg.sender, amount1);
    }

    function pay(
        ERC20 token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        SafeTransferLib.safeTransferFrom(token, payer, recipient, value);
    }

    /*//////////////////////////////////////////////////////////////
                                 LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        address base;
        address speculative;
        uint256 upperBound;
        uint256 amount;
        uint256 sharesMin;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (
            address lendgine,
            uint256 shares,
            uint256 amountB
        )
    {
        LendgineAddress.LendgineKey memory lendgineKey = LendgineAddress.LendgineKey({
            base: params.base,
            speculative: params.speculative,
            upperBound: params.upperBound
        });

        lendgine = LendgineAddress.computeAddress(factory, params.base, params.speculative, params.upperBound);
        address _pair = Lendgine(lendgine).pair();

        shares = Lendgine(lendgine).mint(
            params.recipient,
            params.amount,
            abi.encode(CallbackData({ key: lendgineKey, payer: msg.sender }))
        );

        if (shares < params.sharesMin) revert SlippageError();

        // withdraw entire lp into base tokens
        amountB = shares / 1 ether;

        Pair(_pair).burn(params.recipient, amountB, 0);

        emit Mint(params.recipient, lendgine, shares, params.amount, amountB);
    }

    struct BurnParams {
        address base;
        address speculative;
        uint256 upperBound;
        uint256 burnAmount;
        uint256 speculativeMin;
        uint256 baseMax;
        address recipient;
        uint256 deadline;
    }

    function burn(BurnParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (
            address lendgine,
            uint256 amountS,
            uint256 amountB
        )
    {
        LendgineAddress.LendgineKey memory lendgineKey = LendgineAddress.LendgineKey({
            base: params.base,
            speculative: params.speculative,
            upperBound: params.upperBound
        });

        lendgine = LendgineAddress.computeAddress(factory, params.base, params.speculative, params.upperBound);
        address _pair = Lendgine(lendgine).pair();

        // mint using base assets
        uint256 amountLP = (params.burnAmount * Lendgine(lendgine).totalLiquidityBorrowed()) /
            Lendgine(lendgine).totalSupply();

        amountS = (2 * amountLP * params.upperBound) / 10**36;
        amountB = amountLP / 1 ether;

        if (amountS < params.speculativeMin) revert SlippageError();
        if (amountB > params.baseMax) revert SlippageError();

        Pair(_pair).mint(amountB, 0, abi.encode(CallbackData({ key: lendgineKey, payer: msg.sender })));

        ERC20(lendgine).transferFrom(msg.sender, lendgine, params.burnAmount);
        Lendgine(lendgine).burn(params.recipient);

        emit Burn(msg.sender, lendgine, params.burnAmount, amountS, amountB);
    }
}
