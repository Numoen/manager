// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IPairMintCallback } from "numoen-core/interfaces/IPairMintCallback.sol";

import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import "forge-std/console2.sol";

/// @notice Wraps Numoen liquidity positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LiquidityManager.sol)
/// @author Modified from Uniswap
/// (https://github.com/Uniswap/v3-periphery/blob/main/contracts/NonfungiblePositionManager.sol)
contract LiquidityManager is IPairMintCallback {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed operator, uint256 indexed tokenID, uint256 liquidity, uint256 amount0, uint256 amount1);

    event IncreaseLiquidity(uint256 indexed tokenID, uint256 liquidity, uint256 amount0, uint256 amount1);

    event DecreaseLiquidity(uint256 indexed tokenID, uint256 liquidity, uint256 amount0, uint256 amount1);

    event Collect(uint256 indexed tokenID, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PositionInvalidError();

    error LivelinessError();

    error SlippageError();

    error UnauthorizedError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Position {
        address operator;
        uint80 lendgineID;
        uint24 tick;
        uint256 liquidity;
        uint256 rewardPerLiquidityPaid;
        uint256 tokensOwed;
    }

    mapping(address => uint80) private _lendgineIDs;

    mapping(uint80 => LendgineAddress.LendgineKey) private _lendgineIDToLendgineKey;

    mapping(uint256 => Position) private _positions;

    uint176 private _nextID = 1;

    uint80 private _nextLendgineID = 1;

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

    struct PairMintCallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
    }

    function PairMintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        PairMintCallbackData memory decoded = abi.decode(data, (PairMintCallbackData));
        // TODO: verify sender
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
                        LIQUIDITY MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        address base;
        address speculative;
        uint256 upperBound;
        uint24 tick;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidityMin;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (uint256 tokenID, uint256 liquidity)
    {
        tokenID = _nextID++;
        LendgineAddress.LendgineKey memory lendgineKey = LendgineAddress.LendgineKey({
            base: params.base,
            speculative: params.speculative,
            upperBound: params.upperBound
        });

        address lendgine = LendgineAddress.computeAddress(factory, params.base, params.speculative, params.upperBound);
        address _pair = Lendgine(lendgine).pair();

        liquidity = Pair(_pair).mint(
            params.amount0,
            params.amount1,
            abi.encode(PairMintCallbackData({ key: lendgineKey, payer: msg.sender }))
        );

        if (liquidity < params.liquidityMin) revert SlippageError();

        Lendgine(lendgine).mintMaker(address(this), params.tick);

        uint80 lendgineID = cacheLendgineKey(lendgine, lendgineKey);

        bytes32 positionKey = keccak256(abi.encode(address(this), params.tick));
        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(positionKey);

        _positions[tokenID] = Position({
            operator: params.recipient,
            lendgineID: lendgineID,
            tick: params.tick,
            liquidity: liquidity,
            rewardPerLiquidityPaid: rewardPerLiquidityPaid,
            tokensOwed: 0
        });

        emit Mint(params.recipient, tokenID, liquidity, params.amount0, params.amount1);
    }

    struct IncreaseLiquidityParams {
        uint256 tokenID;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidityMin;
        uint256 deadline;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (uint256 liquidity)
    {
        Position storage position = _positions[params.tokenID];

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        address _pair = Lendgine(lendgine).pair();

        liquidity = Pair(_pair).mint(
            params.amount0,
            params.amount1,
            abi.encode(PairMintCallbackData({ key: lendgineKey, payer: msg.sender }))
        );

        if (liquidity < params.liquidityMin) revert SlippageError();

        Lendgine(lendgine).mintMaker(address(this), position.tick);

        bytes32 positionKey = keccak256(abi.encode(address(this), position.tick));
        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(positionKey);

        position.tokensOwed +=
            (position.liquidity * (rewardPerLiquidityPaid - position.rewardPerLiquidityPaid)) /
            (1 ether * 1 ether);

        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;
        position.liquidity += liquidity;

        emit IncreaseLiquidity(params.tokenID, liquidity, params.amount0, params.amount1);
    }

    struct DecreaseLiquidityParams {
        uint256 tokenID;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidityMax;
        address recipient;
        uint256 deadline;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        checkDeadline(params.deadline)
        returns (uint256 liquidity)
    {
        Position storage position = _positions[params.tokenID];

        if (msg.sender != position.operator) revert UnauthorizedError();

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );
        address _pair = Lendgine(lendgine).pair();

        liquidity = Pair(_pair).calcInvariant(params.amount0, params.amount1);

        if (liquidity > params.liquidityMax) revert SlippageError();

        Lendgine(lendgine).burnMaker(position.tick, liquidity);

        Pair(_pair).burn(params.recipient, params.amount0, params.amount1);

        bytes32 positionKey = keccak256(abi.encode(address(this), position.tick));
        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(positionKey);

        position.tokensOwed +=
            (position.liquidity * (rewardPerLiquidityPaid - position.rewardPerLiquidityPaid)) /
            (1 ether * 1 ether);

        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;

        position.liquidity -= liquidity;

        emit DecreaseLiquidity(params.tokenID, liquidity, params.amount0, params.amount1);
    }

    struct CollectParams {
        uint256 tokenID;
        address recipient;
        uint256 amountMax;
    }

    function collect(CollectParams calldata params) external returns (uint256 amount) {
        Position storage position = _positions[params.tokenID];

        if (msg.sender != position.operator) revert UnauthorizedError();

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound
        );

        bytes32 positionKey = keccak256(abi.encode(address(this), position.tick));
        Lendgine(lendgine).accrueMakerInterest(positionKey, position.tick);

        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(positionKey);

        position.tokensOwed +=
            (position.liquidity * (rewardPerLiquidityPaid - position.rewardPerLiquidityPaid)) /
            (1 ether * 1 ether);

        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;

        Lendgine(lendgine).collectMaker(address(this), position.tick);

        amount = position.tokensOwed > params.amountMax ? params.amountMax : position.tokensOwed;

        SafeTransferLib.safeTransfer(ERC20(lendgineKey.speculative), params.recipient, amount);

        position.tokensOwed -= amount;

        emit Collect(params.tokenID, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function cacheLendgineKey(address lendgine, LendgineAddress.LendgineKey memory lendgineKey)
        private
        returns (uint80 lendgineID)
    {
        lendgineID = _lendgineIDs[lendgine];
        if (lendgineID == 0) {
            _lendgineIDs[lendgine] = (lendgineID = _nextLendgineID++);
            _lendgineIDToLendgineKey[lendgineID] = lendgineKey;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function getPosition(uint256 tokenID)
        external
        view
        returns (
            address operator,
            address base,
            address speculative,
            uint256 upperBound,
            uint24 tick,
            uint256 liquidity,
            uint256 rewardPerLiquidityPaid,
            uint256 tokensOwed
        )
    {
        Position memory position = _positions[tokenID];
        if (position.lendgineID == 0) revert PositionInvalidError();
        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];
        return (
            position.operator,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.upperBound,
            position.tick,
            position.liquidity,
            position.rewardPerLiquidityPaid,
            position.tokensOwed
        );
    }
}
