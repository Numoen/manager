// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { CallbackValidation } from "./libraries/CallbackValidation.sol";
import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";
import { NumoenLibrary } from "./libraries/NumoenLibrary.sol";

/// @notice Facilitates mint and burning Numoen Positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LendgineRouter.sol)
contract LendgineRouter is IMintCallback {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(
        address indexed recipient,
        address indexed lendgine,
        uint256 shares,
        uint256 amountB,
        uint256 amountS,
        uint256 liquidity
    );

    event Burn(
        address indexed payer,
        address indexed lendgine,
        uint256 shares,
        uint256 amountB,
        uint256 amountS,
        uint256 liquidity
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

    function MintCallback(uint256 amountS, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        CallbackValidation.verifyCallback(factory, decoded.key);

        if (amountS > 0) SafeTransferLib.safeTransferFrom(decoded.key.speculative, decoded.payer, msg.sender, amountS);
    }

    /*//////////////////////////////////////////////////////////////
                                 LOGIC
    //////////////////////////////////////////////////////////////*/

    // TODO: use price instead
    struct MintParams {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
        uint256 liquidity;
        uint256 price;
        uint256 sharesMin;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (address lendgine, uint256 shares)
    {
        LendgineAddress.LendgineKey memory lendgineKey = LendgineAddress.LendgineKey({
            base: params.base,
            speculative: params.speculative,
            baseScaleFactor: params.baseScaleFactor,
            speculativeScaleFactor: params.speculativeScaleFactor,
            upperBound: params.upperBound
        });

        lendgine = LendgineAddress.computeLendgineAddress(
            factory,
            params.base,
            params.speculative,
            params.baseScaleFactor,
            params.speculativeScaleFactor,
            params.upperBound
        );
        address pair = LendgineAddress.computePairAddress(
            factory,
            params.base,
            params.speculative,
            params.baseScaleFactor,
            params.speculativeScaleFactor,
            params.upperBound
        );

        shares = Lendgine(lendgine).mint(
            params.recipient,
            Lendgine(lendgine).convertLiquidityToAsset(params.liquidity),
            abi.encode(CallbackData({ key: lendgineKey, payer: msg.sender }))
        );
        if (shares < params.sharesMin) revert SlippageError();

        (uint256 amountBOut, uint256 amountSOut) = NumoenLibrary.priceToReserves(
            params.price,
            params.liquidity,
            params.upperBound
        );
        Pair(pair).burn(params.recipient, amountBOut, amountSOut, params.liquidity);

        emit Mint(params.recipient, lendgine, shares, amountBOut, amountSOut, params.liquidity);
    }

    struct BurnParams {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
        uint256 shares;
        uint256 liquidityMax;
        uint256 price;
        address recipient;
        uint256 deadline;
    }

    function burn(BurnParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (
            address lendgine,
            uint256 amountBIn,
            uint256 amountSIn
        )
    {
        lendgine = LendgineAddress.computeLendgineAddress(
            factory,
            params.base,
            params.speculative,
            params.baseScaleFactor,
            params.speculativeScaleFactor,
            params.upperBound
        );
        address pair = LendgineAddress.computePairAddress(
            factory,
            params.base,
            params.speculative,
            params.baseScaleFactor,
            params.speculativeScaleFactor,
            params.upperBound
        );

        uint256 liquidity = Lendgine(lendgine).convertShareToLiquidity(params.shares);
        if (liquidity > params.liquidityMax) revert SlippageError();

        (amountBIn, amountSIn) = NumoenLibrary.priceToReserves(params.price, liquidity, Pair(pair).upperBound());

        SafeTransferLib.safeTransferFrom(params.base, msg.sender, pair, amountBIn);
        SafeTransferLib.safeTransferFrom(params.speculative, msg.sender, pair, amountSIn);

        Pair(pair).mint(liquidity);

        Lendgine(lendgine).transferFrom(msg.sender, lendgine, params.shares);
        Lendgine(lendgine).burn(params.recipient);

        emit Burn(msg.sender, lendgine, params.shares, amountBIn, amountSIn, liquidity);
    }
}
