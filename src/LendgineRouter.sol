// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "numoen-core/Factory.sol";
import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { IMintCallback } from "numoen-core/interfaces/IMintCallback.sol";
import { LendgineAddress } from "./libraries/LendgineAddress.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import { CallbackValidation } from "./libraries/CallbackValidation.sol";
import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";
import { NumoenLibrary } from "./libraries/NumoenLibrary.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";

import "forge-std/console2.sol";

/// @notice Facilitates mint and burning Numoen Positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LendgineRouter.sol)
contract LendgineRouter is IMintCallback {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed recipient, address indexed lendgine, uint256 shares, uint256 liquidity);

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

    address public immutable uniFactory;

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

    constructor(address _factory, address _uniFactory) {
        factory = _factory;
        uniFactory = _uniFactory;
    }

    /*//////////////////////////////////////////////////////////////
                            CALLBACK LOGIC
    //////////////////////////////////////////////////////////////*/

    struct CallbackData {
        LendgineAddress.LendgineKey key;
        address uniPair;
        uint256 borrowAmount;
        uint256 price;
        address payer;
    }

    function MintCallback(uint256 amountS, bytes calldata data) external override {
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        CallbackValidation.verifyCallback(factory, decoded.key);

        uint256 liquidity = Lendgine(msg.sender).convertAssetToLiquidity(amountS);
        (uint256 amountBOut, uint256 amountSOut) = NumoenLibrary.priceToReserves(
            decoded.price,
            liquidity,
            decoded.key.upperBound
        );

        Pair(Lendgine(msg.sender).pair()).burn(address(this), amountBOut, amountSOut, liquidity);
        SafeTransferLib.safeTransfer(decoded.key.base, decoded.uniPair, amountBOut);

        uint256 sOut = getSOut(amountBOut, decoded.uniPair, decoded.key.base < decoded.key.speculative);
        IUniswapV2Pair(decoded.uniPair).swap(
            decoded.key.base < decoded.key.speculative ? 0 : sOut,
            decoded.key.base < decoded.key.speculative ? sOut : 0,
            msg.sender,
            bytes("")
        );

        SafeTransferLib.safeTransfer(decoded.key.speculative, msg.sender, amountSOut);
        SafeTransferLib.safeTransferFrom(
            decoded.key.speculative,
            decoded.payer,
            msg.sender,
            amountS - sOut - amountSOut
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
        uint256 liquidity;
        uint256 price;
        uint256 slippageBps;
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

        address uniPair = IUniswapV2Factory(uniFactory).getPair(params.base, params.speculative);
        uint256 speculativeAmount = Lendgine(lendgine).convertLiquidityToAsset(params.liquidity);
        uint256 borrowAmount = determineBorrowAmount(
            MathParams({
                speculativeAmount: speculativeAmount,
                upperBound: params.upperBound,
                price: params.price,
                slippageBps: params.slippageBps
            })
        );

        shares = Lendgine(lendgine).mint(
            params.recipient,
            speculativeAmount + borrowAmount,
            abi.encode(
                CallbackData({
                    key: lendgineKey,
                    uniPair: uniPair,
                    borrowAmount: borrowAmount,
                    price: params.price,
                    payer: msg.sender
                })
            )
        );

        if (shares < params.sharesMin) revert SlippageError();
        emit Mint(params.recipient, lendgine, shares, params.liquidity);
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

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MathParams {
        uint256 speculativeAmount;
        uint256 upperBound;
        uint256 price;
        uint256 slippageBps;
    }

    function determineBorrowAmount(MathParams memory params) internal pure returns (uint256) {
        uint256 x0 = PRBMathUD60x18.powu(params.price, 2);
        uint256 x1 = (params.upperBound - params.price) * 2;

        uint256 numerator = PRBMathUD60x18.mul(x1, params.speculativeAmount) +
            ((10000 - params.slippageBps) *
                PRBMathUD60x18.div(PRBMathUD60x18.mul(x0, params.speculativeAmount), params.price)) /
            10000;
        uint256 denominator = 2 *
            params.upperBound -
            (((10000 - params.slippageBps) * PRBMathUD60x18.div(x0, params.price)) / 10000) -
            x1;

        return PRBMathUD60x18.div(numerator, denominator);
    }

    function getSOut(
        uint256 amountBIn,
        address uniPair,
        bool isBase0
    ) internal view returns (uint256) {
        (uint256 u0, uint256 u1, ) = IUniswapV2Pair(uniPair).getReserves();
        uint256 reserveIn = isBase0 ? u0 : u1;
        uint256 reserveOut = isBase0 ? u1 : u0;

        uint256 amountInWithFee = amountBIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }
}
