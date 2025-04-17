// SPDX-License-Identifier: MIT
pragma solidity =0.8.20 ^0.8.20;

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/math/Math.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/interfaces/IChainlinkAggregatorV3.sol

interface IChainlinkAggregatorV3 {
    function decimals() external view returns (uint8 decimals);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/interfaces/IGasPriceOracle.sol

interface IGasPriceOracle {
    function baseFee() external view returns (uint256 _baseFee);

    function baseFeeScalar() external view returns (uint32 _baseFeeScalar);

    function blobBaseFee() external view returns (uint256 _blobBaseFee);

    function blobBaseFeeScalar() external view returns (uint32 _blobBaseFeeScalar);

    function decimals() external pure returns (uint256 _decimals);

    function gasPrice() external view returns (uint256 _gasPrice);

    function getL1Fee(bytes memory _data) external view returns (uint256 _l1Fee);

    function getL1GasUsed(bytes memory _data) external view returns (uint256 _l1GasUsed);

    function isEcotone() external view returns (bool _isEcotone);

    function l1BaseFee() external view returns (uint256 _l1BaseFee);

    function overhead() external view returns (uint256 _overhead);

    function scalar() external view returns (uint256 _scalar);

    function setEcotone() external;

    function version() external view returns (string memory _version);
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/libraries/FlatcoinErrors.sol

library FlatcoinErrors {
    enum PriceSource {
        OnChain,
        OffChain
    }

    error ZeroAddress(string variableName);

    error ZeroValue(string variableName);

    error Paused(bytes32 moduleKey);

    error OnlyOwner(address msgSender);

    error AmountTooSmall(uint256 amount, uint256 minAmount);

    error HighSlippage(uint256 supplied, uint256 accepted);

    /// @dev DelayedOrder
    error MaxFillPriceTooLow(uint256 maxFillPrice, uint256 currentPrice);

    /// @dev DelayedOrder
    error MinFillPriceTooHigh(uint256 minFillPrice, uint256 currentPrice);

    /// @dev DelayedOrder
    error NotEnoughMarginForFees(int256 marginAmount, uint256 feeAmount);

    /// @dev DelayedOrder
    error OrderHasExpired();

    /// @dev DelayedOrder
    error OrderHasNotExpired();

    /// @dev DelayedOrder
    error ExecutableTimeNotReached(uint256 executableTime);

    /// @dev DelayedOrder
    error NotTokenOwner(uint256 tokenId, address msgSender);

    /// @dev DelayedOrder
    error MaxSkewReached(uint256 skewFraction);

    /// @dev DelayedOrder
    error InvalidSkewFractionMax(uint256 skewFractionMax);

    /// @dev DelayedOrder
    error InvalidMaxVelocitySkew(uint256 maxVelocitySkew);

    /// @dev DelayedOrder
    error NotEnoughBalanceForWithdraw(address account, uint256 totalBalance, uint256 withdrawAmount);

    /// @dev DelayedOrder
    error WithdrawalTooSmall(uint256 withdrawAmount, uint256 keeperFee);

    /// @dev DelayedOrder
    error InvariantViolation(string variableName);

    /// @dev DelayedOrder
    error InvalidLeverageCriteria();

    /// @dev DelayedOrder
    error LeverageTooLow(uint256 leverageMin, uint256 leverage);

    /// @dev DelayedOrder
    error LeverageTooHigh(uint256 leverageMax, uint256 leverage);

    /// @dev DelayedOrder
    error MarginTooSmall(uint256 marginMin, uint256 margin);

    /// @dev DelayedOrder
    error DelayedOrderInvalid(address account);

    /// @dev DelayedOrder
    error DepositCapReached(uint256 collateralCap);

    /// @dev DelayedOrder
    error InsufficientGlobalMargin();

    /// @dev LimitOrder
    error LimitOrderInvalid(uint256 tokenId);

    /// @dev LimitOrder
    error LimitOrderPriceNotInRange(uint256 price, uint256 priceLowerThreshold, uint256 priceUpperThreshold);

    /// @dev LimitOrder
    error InvalidThresholds(uint256 priceLowerThreshold, uint256 priceUpperThreshold);

    error InvalidFee(uint256 fee);

    error OnlyAuthorizedModule(address msgSender);

    error ValueNotPositive(string variableName);

    /// @dev LeverageModule
    error MarginMismatchOnClose();

    /// @dev OracleModule
    error RefundFailed();

    error PriceStale(PriceSource priceSource);

    error PriceInvalid(PriceSource priceSource);

    error PriceMismatch(uint256 diffPercent);

    /// @dev OracleModule
    error OracleConfigInvalid();

    /// @dev StableModule
    error PriceImpactDuringWithdraw();

    /// @dev StableModule
    error PriceImpactDuringFullWithdraw();

    /// @dev KeeperFee
    error ETHPriceInvalid();

    /// @dev KeeperFee
    error ETHPriceStale();

    /// @dev Error to emit when a leverage position is not liquidatable.
    /// @param tokenId The token ID of the position.
    error CannotLiquidate(uint256 tokenId);

    error InvalidBounds(uint256 lower, uint256 upper);

    error PositionCreatesBadDebt();

    error ModuleKeyEmpty();

    /// @dev PointsModule
    error MaxVarianceExceeded(string variableName);
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/libraries/FlatcoinModuleKeys.sol

library FlatcoinModuleKeys {
    bytes32 internal constant _STABLE_MODULE_KEY = bytes32("stableModule");
    bytes32 internal constant _LEVERAGE_MODULE_KEY = bytes32("leverageModule");
    bytes32 internal constant _ORACLE_MODULE_KEY = bytes32("oracleModule");
    bytes32 internal constant _DELAYED_ORDER_KEY = bytes32("delayedOrder");
    bytes32 internal constant _LIMIT_ORDER_KEY = bytes32("limitOrder");
    bytes32 internal constant _LIQUIDATION_MODULE_KEY = bytes32("liquidationModule");
    bytes32 internal constant _KEEPER_FEE_MODULE_KEY = bytes32("keeperFee");
    bytes32 internal constant _POINTS_MODULE_KEY = bytes32("pointsModule");
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/interfaces/IOracleModule.sol

interface IOracleModule {
    function onchainOracle() external view returns (IChainlinkAggregatorV3 oracleContract, uint32 maxAge);

    function getPrice() external view returns (uint256 price, uint256 timestamp);

    function getPrice(uint32 maxAge, bool priceDiffCheck) external view returns (uint256 price, uint256 timestamp);

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData) external payable;
}

// src/flattened-contracts/8453/KeeperFee/KeeperFee/src/misc/KeeperFee.sol

// Interfaces

/// @title KeeperFee
/// @notice A dynamic gas fee module to be used on L2s.
/// @dev Adapted from Synthetix PerpsV2DynamicFeesModule.
///      See https://sips.synthetix.io/sips/sip-2013
contract KeeperFee is Ownable {
    using Math for uint256;

    bytes32 public constant MODULE_KEY = FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY;

    IChainlinkAggregatorV3 private _ethOracle; // ETH price for gas unit conversions
    IGasPriceOracle private _gasPriceOracle = IGasPriceOracle(0x420000000000000000000000000000000000000F); // gas price oracle as deployed on Optimism L2 rollups
    IOracleModule private _oracleModule; // for collateral asset pricing (the flatcoin market)

    uint256 private constant _UNIT = 10 ** 18;
    uint256 private _stalenessPeriod;

    address private _assetToPayWith;
    uint256 private _profitMarginUSD;
    uint256 private _profitMarginPercent;
    uint256 private _keeperFeeUpperBound;
    uint256 private _keeperFeeLowerBound;
    uint256 private _gasUnitsL1;
    uint256 private _gasUnitsL2;

    constructor(
        address owner,
        address ethOracle,
        address oracleModule,
        address assetToPayWith,
        uint256 profitMarginUSD,
        uint256 profitMarginPercent,
        uint256 keeperFeeUpperBound,
        uint256 keeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2,
        uint256 stalenessPeriod
    ) Ownable(owner) {
        // contracts
        _ethOracle = IChainlinkAggregatorV3(ethOracle);
        _oracleModule = IOracleModule(oracleModule);

        // params
        _assetToPayWith = assetToPayWith;
        _profitMarginUSD = profitMarginUSD;
        _profitMarginPercent = profitMarginPercent;
        _keeperFeeUpperBound = keeperFeeUpperBound; // In USD
        _keeperFeeLowerBound = keeperFeeLowerBound; // In USD
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
        _stalenessPeriod = stalenessPeriod;

        // Check that the oracle asset price is valid
        (uint256 assetPrice, ) = IOracleModule(oracleModule).getPrice();

        if (assetPrice <= 0) revert FlatcoinErrors.PriceInvalid(FlatcoinErrors.PriceSource.OnChain);

        (, , , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

        // Check that the ETH oracle price is fresh.
        if (block.timestamp >= ethPriceupdatedAt + stalenessPeriod) revert FlatcoinErrors.ETHPriceStale();
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @dev Returns computed gas price given on-chain variables.
    function getKeeperFee() public view returns (uint256 keeperFeeCollateral) {
        return getKeeperFee(_gasPriceOracle.baseFee());
    }

    function getKeeperFee(uint256 baseFee) public view returns (uint256 keeperFeeCollateral) {
        uint256 ethPrice18;
        uint256 collateralPrice;
        {
            uint256 timestamp;

            (, int256 ethPrice, , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

            if (block.timestamp >= ethPriceupdatedAt + _stalenessPeriod) revert FlatcoinErrors.ETHPriceStale();
            if (ethPrice <= 0) revert FlatcoinErrors.ETHPriceInvalid();

            ethPrice18 = uint256(ethPrice) * 1e10; // from 8 decimals to 18
            // NOTE: Currently the market asset and collateral asset are the same.
            // If this changes in the future, then the following line should fetch the collateral asset, not market asset.
            (, uint32 maxAge) = _oracleModule.onchainOracle();
            (collateralPrice, timestamp) = _oracleModule.getPrice();

            if (collateralPrice <= 0) revert FlatcoinErrors.PriceInvalid(FlatcoinErrors.PriceSource.OnChain);

            if (block.timestamp >= timestamp + maxAge)
                revert FlatcoinErrors.PriceStale(FlatcoinErrors.PriceSource.OnChain);
        }

        bool isEcotone;
        try _gasPriceOracle.isEcotone() returns (bool _isEcotone) {
            isEcotone = _isEcotone;
        } catch {
            // If the call fails, we assume it's not an ecotone. Explicitly setting it to false to avoid missunderstandings.
            isEcotone = false;
        }

        uint256 costOfExecutionGrossEth;

        // Note: The OVM GasPriceOracle scales the L1 gas fee by the decimals
        // Reference function `_getL1FeeBedrock` https://github.com/ethereum-optimism/optimism/blob/af9aa3369de8c3cbef0e491024fb83590492366c/packages/contracts-bedrock/src/L2/GasPriceOracle.sol#L128
        // The Synthetix implementation can be found in function `getCostofExecutionEth` https://github.com/Synthetixio/synthetix-v3/blob/e7932e96d8153db0716f1e5dd6df78c1a1ec711e/auxiliary/OpGasPriceOracle/contracts/OpGasPriceOracle.sol#L72
        if (isEcotone) {
            // If it's an ecotone, use the new formula and interface
            uint256 gasPriceL2 = baseFee;
            uint256 baseFeeScalar = _gasPriceOracle.baseFeeScalar();
            uint256 l1BaseFee = _gasPriceOracle.l1BaseFee();
            uint256 blobBaseFeeScalar = _gasPriceOracle.blobBaseFeeScalar();
            uint256 blobBaseFee = _gasPriceOracle.blobBaseFee();
            uint256 decimals = _gasPriceOracle.decimals();

            uint256 l1GasPrice = (baseFeeScalar * l1BaseFee * 16 + blobBaseFeeScalar * blobBaseFee) /
                (16 * 10 ** decimals);

            costOfExecutionGrossEth = ((_gasUnitsL1 * l1GasPrice) + (_gasUnitsL2 * gasPriceL2));
        } else {
            // If it's not an ecotone, use the legacy formula and interface.
            uint256 gasPriceL2 = baseFee; // baseFee and gasPrice are the same in the legacy contract. Both return block.basefee.
            uint256 overhead = _gasPriceOracle.overhead();
            uint256 l1BaseFee = _gasPriceOracle.l1BaseFee();
            uint256 decimals = _gasPriceOracle.decimals();
            uint256 scalar = _gasPriceOracle.scalar();

            costOfExecutionGrossEth = ((((_gasUnitsL1 + overhead) * l1BaseFee * scalar) / 10 ** decimals) +
                (_gasUnitsL2 * gasPriceL2));
        }

        uint256 costOfExecutionGrossUSD = costOfExecutionGrossEth.mulDiv(ethPrice18, _UNIT); // fee priced in USD

        uint256 maxProfitMargin = _profitMarginUSD.max(costOfExecutionGrossUSD.mulDiv(_profitMarginPercent, _UNIT)); // additional USD profit for the keeper
        uint256 costOfExecutionNet = costOfExecutionGrossUSD + maxProfitMargin; // fee priced in USD

        keeperFeeCollateral = (_keeperFeeUpperBound.min(costOfExecutionNet.max(_keeperFeeLowerBound))).mulDiv(
            _UNIT,
            collateralPrice
        ); // fee priced in collateral
    }

    /// @dev Returns the current configurations.
    function getConfig()
        external
        view
        returns (
            address gasPriceOracle,
            uint256 profitMarginUSD,
            uint256 profitMarginPercent,
            uint256 keeperFeeUpperBound,
            uint256 keeperFeeLowerBound,
            uint256 gasUnitsL1,
            uint256 gasUnitsL2,
            uint256 stalenessPeriod
        )
    {
        gasPriceOracle = address(_gasPriceOracle);
        profitMarginUSD = _profitMarginUSD;
        profitMarginPercent = _profitMarginPercent;
        keeperFeeUpperBound = _keeperFeeUpperBound;
        keeperFeeLowerBound = _keeperFeeLowerBound;
        gasUnitsL1 = _gasUnitsL1;
        gasUnitsL2 = _gasUnitsL2;
        stalenessPeriod = _stalenessPeriod;
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @dev Sets params used for gas price computation.
    function setParameters(
        uint256 profitMarginUSD,
        uint256 profitMarginPercent,
        uint256 keeperFeeUpperBound,
        uint256 keeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2
    ) external onlyOwner {
        _profitMarginUSD = profitMarginUSD;
        _profitMarginPercent = profitMarginPercent;
        _keeperFeeUpperBound = keeperFeeUpperBound;
        _keeperFeeLowerBound = keeperFeeLowerBound;
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
    }

    /// @dev Sets keeper fee upper and lower bounds.
    /// @param keeperFeeUpperBound The upper bound of the keeper fee in USD.
    /// @param keeperFeeLowerBound The lower bound of the keeper fee in USD.
    function setParameters(uint256 keeperFeeUpperBound, uint256 keeperFeeLowerBound) external onlyOwner {
        if (keeperFeeUpperBound <= keeperFeeLowerBound) revert FlatcoinErrors.InvalidFee(keeperFeeLowerBound);
        if (keeperFeeLowerBound == 0) revert FlatcoinErrors.ZeroValue("keeperFeeLowerBound");

        _keeperFeeUpperBound = keeperFeeUpperBound;
        _keeperFeeLowerBound = keeperFeeLowerBound;
    }

    /// @dev Sets a custom gas price oracle. May be needed for some chain deployments.
    function setGasPriceOracle(address gasPriceOracle) external onlyOwner {
        if (address(gasPriceOracle) == address(0)) revert FlatcoinErrors.ZeroAddress("gasPriceOracle");

        _gasPriceOracle = IGasPriceOracle(gasPriceOracle);
    }

    /// @dev Sets the staleness period for the ETH oracle.
    function setStalenessPeriod(uint256 stalenessPeriod) external onlyOwner {
        if (stalenessPeriod == 0) revert FlatcoinErrors.ZeroValue("stalenessPeriod");

        _stalenessPeriod = stalenessPeriod;
    }
}
