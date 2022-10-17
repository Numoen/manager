// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";

import { CallbackValidation } from "./libraries/CallbackValidation.sol";
import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";
import { LendgineAddress } from "./libraries/LendgineAddress.sol";

import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";

import "forge-std/console2.sol";

/// @notice Facilitates mint and burning Numoen Positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LendgineRouter.sol)
contract LendgineRouter is IMintCallback {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed recipient, address indexed lendgine, uint256 shares, uint256 amountS, uint256 amountB);

    event Burn(address indexed payer, address indexed lendgine, uint256 shares, uint256 amountS, uint256 amountB);

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

    function MintCallback(uint256 amountS, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        CallbackValidation.verifyCallback(factory, decoded.key);

        if (amountS > 0) SafeTransferLib.safeTransferFrom(decoded.key.speculative, decoded.payer, msg.sender, amountS);
    }

    /*//////////////////////////////////////////////////////////////
                                 LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        address base;
        address speculative;
        uint256 upperBound;
        uint256 amountS;
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

        lendgine = Factory(factory).getLendgine(params.base, params.speculative, params.upperBound);
        address _pair = Lendgine(lendgine).pair();

        shares = Lendgine(lendgine).mint(
            params.recipient,
            params.amountS,
            abi.encode(CallbackData({ key: lendgineKey, payer: msg.sender }))
        );

        uint256 liquidity = Lendgine(lendgine).convertShareToLiquidity(shares);

        if (shares < params.sharesMin) revert SlippageError();

        // withdraw entire lp into base tokens
        uint256 upperBound = Pair(_pair).upperBound();
        amountB = ((upperBound**2) * liquidity) / (1 ether * 1 ether);

        Pair(_pair).burn(params.recipient, amountB, 0, liquidity);

        emit Mint(params.recipient, lendgine, shares, params.amountS, amountB);
    }

    struct BurnParams {
        address base;
        address speculative;
        uint256 upperBound;
        uint256 shares;
        uint256 amountSMin;
        uint256 amountBMax;
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
        lendgine = Factory(factory).getLendgine(params.base, params.speculative, params.upperBound);
        address _pair = Lendgine(lendgine).pair();

        uint256 liquidity = Lendgine(lendgine).convertShareToLiquidity(params.shares);
        amountS = Lendgine(lendgine).convertLiquidityToAsset(liquidity);
        uint256 upperBound = Pair(_pair).upperBound();
        amountB = ((upperBound**2) * liquidity) / (1 ether * 1 ether);

        if (amountS < params.amountSMin) revert SlippageError();
        if (amountB > params.amountBMax) revert SlippageError();

        SafeTransferLib.safeTransferFrom(params.base, msg.sender, _pair, amountB);
        Pair(_pair).mint(liquidity);

        Lendgine(lendgine).transferFrom(msg.sender, lendgine, params.shares);
        Lendgine(lendgine).burn(params.recipient);

        emit Burn(msg.sender, lendgine, params.shares, amountS, amountB);
    }
}
