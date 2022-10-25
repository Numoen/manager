// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { CallbackValidation } from "./libraries/CallbackValidation.sol";
import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";

import { Lendgine } from "numoen-core/Lendgine.sol";
import { Pair } from "numoen-core/Pair.sol";
import { LendgineAddress } from "numoen-core/libraries/LendgineAddress.sol";

import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

import "forge-std/console2.sol";

/// @notice Wraps Numoen liquidity positions
/// @author Kyle Scott (https://github.com/numoen/manager/blob/master/src/LiquidityManager.sol)
/// @author Modified from Uniswap
/// (https://github.com/Uniswap/v3-periphery/blob/main/contracts/NonfungiblePositionManager.sol)
contract LiquidityManager {
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

    error CollectError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Position {
        uint256 liquidity;
        uint256 rewardPerLiquidityPaid;
        uint256 tokensOwed;
        uint80 lendgineID;
        address operator;
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
                        LIQUIDITY MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

    struct MintParams {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidity;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params) external checkDeadline(params.deadline) returns (uint256 tokenID) {
        tokenID = _nextID++;
        LendgineAddress.LendgineKey memory lendgineKey = LendgineAddress.LendgineKey({
            base: params.base,
            speculative: params.speculative,
            baseScaleFactor: params.baseScaleFactor,
            speculativeScaleFactor: params.speculativeScaleFactor,
            upperBound: params.upperBound
        });

        address lendgine = LendgineAddress.computeLendgineAddress(
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

        SafeTransferLib.safeTransferFrom(params.base, msg.sender, pair, params.amount0);
        SafeTransferLib.safeTransferFrom(params.speculative, msg.sender, pair, params.amount1);
        Pair(pair).mint(params.liquidity);
        Lendgine(lendgine).deposit(address(this));

        uint80 lendgineID = cacheLendgineKey(lendgine, lendgineKey);
        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(address(this));

        _positions[tokenID] = Position({
            operator: params.recipient,
            lendgineID: lendgineID,
            liquidity: params.liquidity,
            rewardPerLiquidityPaid: rewardPerLiquidityPaid,
            tokensOwed: 0
        });

        emit Mint(params.recipient, tokenID, params.liquidity, params.amount0, params.amount1);
    }

    struct IncreaseLiquidityParams {
        uint256 tokenID;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidity;
        uint256 deadline;
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params) external checkDeadline(params.deadline) {
        Position storage position = _positions[params.tokenID];

        if (msg.sender != position.operator) revert UnauthorizedError();
        if (position.lendgineID == 0) revert PositionInvalidError();

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeLendgineAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );
        address pair = LendgineAddress.computePairAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );

        SafeTransferLib.safeTransferFrom(lendgineKey.base, msg.sender, pair, params.amount0);
        SafeTransferLib.safeTransferFrom(lendgineKey.speculative, msg.sender, pair, params.amount1);
        Pair(pair).mint(params.liquidity);
        Lendgine(lendgine).deposit(address(this));

        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(address(this));

        position.tokensOwed += PRBMathUD60x18.mul(
            position.liquidity,
            rewardPerLiquidityPaid - position.rewardPerLiquidityPaid
        );
        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;
        position.liquidity += params.liquidity;

        emit IncreaseLiquidity(params.tokenID, params.liquidity, params.amount0, params.amount1);
    }

    struct DecreaseLiquidityParams {
        uint256 tokenID;
        uint256 amount0;
        uint256 amount1;
        uint256 liquidity;
        address recipient;
        uint256 deadline;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params) external checkDeadline(params.deadline) {
        Position storage position = _positions[params.tokenID];

        if (msg.sender != position.operator) revert UnauthorizedError();
        if (position.lendgineID == 0) revert PositionInvalidError();

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeLendgineAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );
        address pair = LendgineAddress.computePairAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );

        Lendgine(lendgine).withdraw(params.liquidity);
        Pair(pair).burn(params.recipient, params.amount0, params.amount1, params.liquidity);

        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(address(this));

        position.tokensOwed += PRBMathUD60x18.mul(
            position.liquidity,
            rewardPerLiquidityPaid - position.rewardPerLiquidityPaid
        );
        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;
        position.liquidity -= params.liquidity;

        emit DecreaseLiquidity(params.tokenID, params.liquidity, params.amount0, params.amount1);
    }

    struct CollectParams {
        uint256 tokenID;
        address recipient;
        uint256 amountRequested;
    }

    function collect(CollectParams calldata params) external returns (uint256 amount) {
        Position storage position = _positions[params.tokenID];

        if (msg.sender != position.operator) revert UnauthorizedError();
        if (position.lendgineID == 0) revert PositionInvalidError();

        LendgineAddress.LendgineKey memory lendgineKey = _lendgineIDToLendgineKey[position.lendgineID];

        address lendgine = LendgineAddress.computeLendgineAddress(
            factory,
            lendgineKey.base,
            lendgineKey.speculative,
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound
        );

        Lendgine(lendgine).accruePositionInterest();
        (, uint256 rewardPerLiquidityPaid, ) = Lendgine(lendgine).positions(address(this));

        position.tokensOwed += PRBMathUD60x18.mul(
            position.liquidity,
            rewardPerLiquidityPaid - position.rewardPerLiquidityPaid
        );
        position.rewardPerLiquidityPaid = rewardPerLiquidityPaid;

        amount = params.amountRequested > position.tokensOwed ? position.tokensOwed : params.amountRequested;
        position.tokensOwed -= amount;

        uint256 amountSent = Lendgine(lendgine).collect(params.recipient, amount);

        if (amountSent < amount) revert CollectError();

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
            uint256 baseScaleFactor,
            uint256 speculativeScaleFactor,
            uint256 upperBound,
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
            lendgineKey.baseScaleFactor,
            lendgineKey.speculativeScaleFactor,
            lendgineKey.upperBound,
            position.liquidity,
            position.rewardPerLiquidityPaid,
            position.tokensOwed
        );
    }
}
