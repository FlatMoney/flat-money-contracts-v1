// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity =0.8.20 ^0.8.0 ^0.8.20;

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/math/SignedMath.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// lib/pyth-sdk-solidity/IPythEvents.sol

/// @title IPythEvents contains the events that Pyth contract emits.
/// @dev This interface can be used for listening to the updates for off-chain and testing purposes.
interface IPythEvents {
    /// @dev Emitted when the price feed with `id` has received a fresh update.
    /// @param id The Pyth Price Feed ID.
    /// @param publishTime Publish time of the given price update.
    /// @param price Price of the given price update.
    /// @param conf Confidence interval of the given price update.
    event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf);

    /// @dev Emitted when a batch price update is processed successfully.
    /// @param chainId ID of the source chain that the batch price update comes from.
    /// @param sequenceNumber Sequence number of the batch price update.
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);
}

// lib/pyth-sdk-solidity/PythStructs.sol

contract PythStructs {
    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/consumers/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }
}

// src/interfaces/IChainlinkAggregatorV3.sol

interface IChainlinkAggregatorV3 {
    function decimals() external view returns (uint8 decimals);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// src/interfaces/ILiquidationModule.sol

interface ILiquidationModule {
    function canLiquidate(uint256 tokenId) external view returns (bool liquidatable);

    function canLiquidate(uint256 tokenId, uint256 price) external view returns (bool liquidatable);

    function getLiquidationFee(uint256 tokenId) external view returns (uint256 liquidationFee);

    function getLiquidationMargin(uint256 additionalSize) external view returns (uint256 liquidationMargin);

    function getLiquidationMargin(
        uint256 additionalSize,
        uint256 price
    ) external view returns (uint256 liquidationMargin);

    function liquidate(uint256 tokenId) external;

    function liquidate(uint256 tokenID, bytes[] memory priceUpdateData) external payable;

    function liquidationBufferRatio() external view returns (uint128 liquidationBufferRatio);

    function liquidationFeeLowerBound() external view returns (uint256 feeLowerBound);

    function liquidationFeeRatio() external view returns (uint128 liquidationFeeRatio);

    function liquidationFeeUpperBound() external view returns (uint256 feeUpperBound);

    function liquidationPrice(uint256 tokenId) external view returns (uint256 liqPrice);

    function liquidationPrice(uint256 tokenId, uint256 price) external view returns (uint256 liqPrice);

    function setLiquidationBufferRatio(uint128 _newLiquidationBufferRatio) external;

    function setLiquidationFeeRatio(uint128 _newLiquidationFeeRatio) external;
}

// src/libraries/DecimalMath.sol

/// @title DecimalMath
/// @author dHEDGE
/// @author Adapted from Synthetix <https://github.com/Synthetixio/synthetix/blob/cbd8666f4331ee95fcc667ec7345d13c8ba77efb/contracts/SignedSafeDecimalMath.sol>
///         and  <https://github.com/Synthetixio/synthetix/blob/cbd8666f4331ee95fcc667ec7345d13c8ba77efb/contracts/SafeDecimalMath.sol>
/// @notice Library for fixed point math.
// TODO: Explore if Solmate FixedPointMathLib can be used instead. <https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol>
// solhint-disable gas-named-return-values
library DecimalMath {
    /* Number of decimal places in the representations. */
    uint8 public constant DECIMALS = 18;
    uint8 public constant HIGH_PRECISION_DECIMALS = 27;

    /* The number representing 1.0. */
    int256 public constant UNIT = 1e18;

    /* The number representing 1.0 for higher fidelity numbers. */
    int256 public constant PRECISE_UNIT = int256(10 ** uint256(HIGH_PRECISION_DECIMALS));
    int256 private constant _UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR =
        int256(10 ** uint256(HIGH_PRECISION_DECIMALS - DECIMALS));

    /**
     * @return The result of multiplying x and y, interpreting the operands as fixed-point
     * decimals.
     *
     * @dev A unit factor is divided out after the product of x and y is evaluated,
     * so that product must be less than 2**256. As this is an integer division,
     * the internal division always rounds down. This helps save on gas. Rounding
     * is more expensive on gas.
     */
    function _multiplyDecimal(int256 x, int256 y) internal pure returns (int256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return (x * y) / UNIT;
    }

    /**
     * @return The result of multiplying x and y, interpreting the operands as fixed-point
     * decimals.
     *
     * @dev A unit factor is divided out after the product of x and y is evaluated,
     * so that product must be less than 2**256. As this is an integer division,
     * the internal division always rounds down. This helps save on gas. Rounding
     * is more expensive on gas.
     */
    function _multiplyDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return (x * y) / uint256(UNIT);
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a precise unit.
     *
     * @dev The operands should be in the precise unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRoundPrecise(int256 x, int256 y) internal pure returns (int256) {
        return _multiplyDecimalRound(x, y, PRECISE_UNIT);
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a precise unit.
     *
     * @dev The operands should be in the precise unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRoundPrecise(uint256 x, uint256 y) internal pure returns (uint256) {
        return _multiplyDecimalRound(x, y, uint256(PRECISE_UNIT));
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a standard unit.
     *
     * @dev The operands should be in the standard unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRound(int256 x, int256 y) internal pure returns (int256) {
        return _multiplyDecimalRound(x, y, UNIT);
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a standard unit.
     *
     * @dev The operands should be in the standard unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRound(uint256 x, uint256 y) internal pure returns (uint256) {
        return _multiplyDecimalRound(x, y, uint256(UNIT));
    }

    /**
     * @return The result of safely dividing x and y. The return value is a high
     * precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and UNIT must be less than 2**256. As
     * this is an integer division, the result is always rounded down.
     * This helps save on gas. Rounding is more expensive on gas.
     */
    function _divideDecimal(int256 x, int256 y) internal pure returns (int256) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return (x * UNIT) / y;
    }

    /**
     * @return The result of safely dividing x and y. The return value is a high
     * precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and UNIT must be less than 2**256. As
     * this is an integer division, the result is always rounded down.
     * This helps save on gas. Rounding is more expensive on gas.
     */
    function _divideDecimal(uint256 x, uint256 y) internal pure returns (uint256) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return (x * uint256(UNIT)) / y;
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * standard precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and the standard precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRound(int256 x, int256 y) internal pure returns (int256) {
        return _divideDecimalRound(x, y, UNIT);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * high precision decimal.
     *
     * @dev y is divided after the product of x and the high precision unit
     * is evaluated, so the product of x and the high precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRoundPrecise(int256 x, int256 y) internal pure returns (int256) {
        return _divideDecimalRound(x, y, PRECISE_UNIT);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * high precision decimal.
     *
     * @dev y is divided after the product of x and the high precision unit
     * is evaluated, so the product of x and the high precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRoundPrecise(uint256 x, uint256 y) internal pure returns (uint256) {
        return _divideDecimalRound(x, y, uint256(PRECISE_UNIT));
    }

    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function _decimalToPreciseDecimal(int256 i) internal pure returns (int256) {
        return i * _UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
    }

    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function _decimalToPreciseDecimal(uint256 i) internal pure returns (uint256) {
        return i * uint256(_UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
    }

    /**
     * @dev Convert a high precision decimal to a standard decimal representation.
     */
    function _preciseDecimalToDecimal(int256 i) internal pure returns (int256) {
        int256 quotientTimesTen = i / (_UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
        return _roundDividingByTen(quotientTimesTen);
    }

    /**
     * @dev Convert a high precision decimal to a standard decimal representation.
     */
    function _preciseDecimalToDecimal(uint256 i) internal pure returns (uint256) {
        uint256 quotientTimesTen = i / (uint256(_UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR) / 10);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen += 10;
        }

        return quotientTimesTen / 10;
    }

    /**
     * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
     * Half increments round away from zero; positive numbers at a half increment are rounded up,
     * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
     * unsigned version of this library (SafeDecimalMath).
     */
    function _roundDividingByTen(int256 valueTimesTen) private pure returns (int256) {
        int256 increment;
        if (valueTimesTen % 10 >= 5) {
            increment = 10;
        } else if (valueTimesTen % 10 <= -5) {
            increment = -10;
        }
        return (valueTimesTen + increment) / 10;
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of the specified precision unit.
     *
     * @dev The operands should be in the form of a the specified unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRound(int256 x, int256 y, int256 precisionUnit) private pure returns (int256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        int256 quotientTimesTen = (x * y) / (precisionUnit / 10);
        return _roundDividingByTen(quotientTimesTen);
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of the specified precision unit.
     *
     * @dev The operands should be in the form of a the specified unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function _multiplyDecimalRound(uint256 x, uint256 y, uint256 precisionUnit) private pure returns (uint256) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        uint256 quotientTimesTen = (x * y) / (precisionUnit / 10);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen += 10;
        }

        return quotientTimesTen / 10;
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * decimal in the precision unit specified in the parameter.
     *
     * @dev y is divided after the product of x and the specified precision unit
     * is evaluated, so the product of x and the specified precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRound(int256 x, int256 y, int256 precisionUnit) private pure returns (int256) {
        int256 resultTimesTen = (x * precisionUnit * 10) / y;
        return _roundDividingByTen(resultTimesTen);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * decimal in the precision unit specified in the parameter.
     *
     * @dev y is divided after the product of x and the specified precision unit
     * is evaluated, so the product of x and the specified precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRound(uint256 x, uint256 y, uint256 precisionUnit) private pure returns (uint256) {
        uint256 resultTimesTen = (x * (precisionUnit * 10)) / y;

        if (resultTimesTen % 10 >= 5) {
            resultTimesTen += 10;
        }

        return resultTimesTen / 10;
    }
}

// src/libraries/FlatcoinErrors.sol

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
    error DepositCapReached(uint256 collateralCap);

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

    /// @dev FlatcoinVault
    error InsufficientGlobalMargin();

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

// src/libraries/FlatcoinModuleKeys.sol

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

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {}

    function __Context_init_unchained() internal onlyInitializing {}
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

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// src/interfaces/IOracleModule.sol

interface IOracleModule {
    function onchainOracle() external view returns (IChainlinkAggregatorV3 oracleContract, uint32 maxAge);

    function getPrice() external view returns (uint256 price, uint256 timestamp);

    function getPrice(uint32 maxAge, bool priceDiffCheck) external view returns (uint256 price, uint256 timestamp);

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData) external payable;
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation =
        0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

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
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Enumerable.sol)

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// lib/pyth-sdk-solidity/IPyth.sol

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/consumers/best-practices for how to consume prices safely.
/// @author Pyth Data Association
interface IPyth is IPythEvents {
    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param publishTimes Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param updateData Array of price update data.
    /// @return feeAmount The required fee in Wei.
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);

    /// @notice Parse `updateData` and return price feeds of the given `priceIds` if they are all published
    /// within `minPublishTime` and `maxPublishTime`.
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `updatePriceFeeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param minPublishTime minimum acceptable publishTime for the given `priceIds`.
    /// @param maxPublishTime maximum acceptable publishTime for the given `priceIds`.
    /// @return priceFeeds Array of the price feeds corresponding to the given `priceIds` (with the same order).
    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
}

// src/libraries/FlatcoinStructs.sol

library FlatcoinStructs {
    enum OrderType {
        None, // 0
        StableDeposit, // 1
        StableWithdraw, // 2
        LeverageOpen, // 3
        LeverageClose, // 4
        LeverageAdjust, // 5
        LimitClose // 6
    }

    enum LimitOrderExecutionType {
        None, // 0
        StopLoss, // 1
        ProfitTake // 2
    }

    /// @notice Global position data
    /// @dev This is the consolidated data of all leverage positions used to calculate funding fees and total profit and loss.
    /// @dev One can imagine this as being the data of a single big position on leverage side against the stable side.
    /// @param marginDepositedTotal Total collateral deposited for leverage trade positions.
    /// @param averagePrice The last time funding fees and profit and loss were settled.
    /// @param sizeOpenedTotal The total size of leverage across all trades on entry.
    struct GlobalPositions {
        int256 marginDepositedTotal;
        uint256 averagePrice;
        uint256 sizeOpenedTotal;
    }

    /// @notice Individual leverage position
    struct Position {
        uint256 averagePrice;
        uint256 marginDeposited;
        uint256 additionalSize;
        int256 entryCumulativeFunding;
    }

    struct MarketSummary {
        int256 profitLossTotalByLongs;
        int256 accruedFundingTotalByLongs;
        int256 currentFundingRate;
        int256 nextFundingEntry;
    }

    struct PositionSummary {
        int256 profitLoss;
        int256 accruedFunding;
        int256 marginAfterSettlement;
    }

    struct VaultSummary {
        int256 marketSkew;
        int256 cumulativeFundingRate;
        int256 lastRecomputedFundingRate;
        uint64 lastRecomputedFundingTimestamp;
        uint256 stableCollateralTotal;
        GlobalPositions globalPositions;
    }

    struct Order {
        OrderType orderType;
        uint256 keeperFee; // The deposit paid upon submitting that needs to be paid / refunded on tx confirmation
        uint64 executableAtTime; // The timestamp at which this order is executable at
        bytes orderData;
    }

    struct AnnouncedStableDeposit {
        uint256 depositAmount;
        uint256 minAmountOut; // The minimum amount of tokens expected to receive back
    }

    struct AnnouncedStableWithdraw {
        uint256 withdrawAmount;
        uint256 minAmountOut; // The minimum amount of underlying tokens expected to receive back
    }

    struct AnnouncedLeverageOpen {
        uint256 margin; // The margin amount to be used as leverage collateral
        uint256 additionalSize; // The additional size exposure (leverage)
        uint256 maxFillPrice; // The maximum price accepted by the user
        uint256 tradeFee;
    }

    struct AnnouncedLeverageAdjust {
        uint256 tokenId;
        int256 marginAdjustment;
        int256 additionalSizeAdjustment;
        uint256 fillPrice; // should be passed depending on the type of additionalSizeAdjustment
        uint256 tradeFee;
        uint256 totalFee;
    }

    // Note: the tradeFee is determined at time of execution
    struct LimitClose {
        // Note: the tradeFee is determined at time of execution
        uint256 tokenId;
        uint256 priceLowerThreshold;
        uint256 priceUpperThreshold;
    }

    struct AnnouncedLeverageClose {
        uint256 tokenId; // The NFT of the position
        uint256 minFillPrice; // The minimum price accepted by the user
        uint256 tradeFee;
    }

    struct OnchainOracle {
        IChainlinkAggregatorV3 oracleContract; // Chainlink oracle contract
        uint32 maxAge; // Oldest price that is acceptable to use
    }

    struct OffchainOracle {
        IPyth oracleContract; // Pyth network oracle contract
        bytes32 priceId; // Pyth network price Id
        uint32 maxAge; // Oldest price that is acceptable to use
        uint32 minConfidenceRatio; // the minimum Pyth oracle price / expo ratio. The higher, the more confident the accuracy of the price.
    }

    struct AuthorizedModule {
        bytes32 moduleKey;
        address moduleAddress;
    }

    struct LeveragePositionData {
        uint256 tokenId;
        uint256 averagePrice;
        uint256 marginDeposited;
        uint256 additionalSize;
        int256 entryCumulativeFunding;
        int256 profitLoss;
        int256 accruedFunding;
        int256 marginAfterSettlement;
        uint256 liquidationPrice;
        uint256 limitOrderPriceLowerThreshold;
        uint256 limitOrderPriceUpperThreshold;
    }

    struct MintRate {
        uint256 lastAccumulatedMint;
        uint256 maxAccumulatedMint;
        uint64 lastMintTimestamp;
        uint64 decayTime;
    }
}

// src/interfaces/ILimitOrder.sol

interface ILimitOrder {
    function announceLimitOrder(uint256 tokenId, uint256 priceLowerThreshold, uint256 priceUpperThreshold) external;

    function cancelExistingLimitOrder(uint256 tokenId) external returns (bool cancelled);

    function cancelLimitOrder(uint256 tokenId) external;

    function executeLimitOrder(uint256 tokenId, bytes[] memory priceUpdateData) external payable;

    function getLimitOrder(uint256 tokenId) external view returns (FlatcoinStructs.Order memory order);

    function resetExecutionTime(uint256 tokenId) external;
}

// src/libraries/FlatcoinEvents.sol

library FlatcoinEvents {
    event OrderAnnounced(address account, FlatcoinStructs.OrderType orderType, uint256 keeperFee);

    event OrderExecuted(address account, FlatcoinStructs.OrderType orderType, uint256 keeperFee);

    event OrderCancelled(address account, FlatcoinStructs.OrderType orderType);

    event Deposit(address depositor, uint256 depositAmount, uint256 mintedAmount);

    event Withdraw(address withdrawer, uint256 withdrawAmount, uint256 burnedAmount);

    event LeverageOpen(address account, uint256 tokenId, uint256 entryPrice);

    event LeverageAdjust(uint256 tokenId, uint256 averagePrice, uint256 adjustPrice);

    event LeverageClose(uint256 tokenId, uint256 closePrice, FlatcoinStructs.PositionSummary positionSummary);

    event SetAsset(address asset);

    event SetOnChainOracle(FlatcoinStructs.OnchainOracle oracle);

    event SetOffChainOracle(FlatcoinStructs.OffchainOracle oracle);

    event PositionLiquidated(
        uint256 tokenId,
        address liquidator,
        uint256 liquidationFee,
        uint256 closePrice,
        FlatcoinStructs.PositionSummary positionSummary
    );

    event LiquidationFeeRatioModified(uint256 oldRatio, uint256 newRatio);

    event LiquidationBufferRatioModified(uint256 oldRatio, uint256 newRatio);

    event LiquidationFeeBoundsModified(uint256 oldMin, uint256 oldMax, uint256 newMin, uint256 newMax);

    event VaultAddressModified(address oldAddress, address newAddress);

    event LiquidationFundsDeposited(address depositor, uint256 amount);

    event LiquidationFeesWithdrawn(uint256 amount);

    event SetMaxDiffPercent(uint256 maxDiffPercent);

    event LimitOrderAnnounced(
        address account,
        uint256 tokenId,
        uint256 priceLowerThreshold,
        uint256 priceUpperThreshold
    );

    event LimitOrderExecuted(
        address account,
        uint256 tokenId,
        uint256 keeperFee,
        uint256 price,
        FlatcoinStructs.LimitOrderExecutionType limitOrderType
    );

    event LimitOrderCancelled(address account, uint256 tokenId);
}

// src/interfaces/IFlatcoinVault.sol

interface IFlatcoinVault {
    function collateral() external view returns (IERC20 collateral);

    function lastRecomputedFundingTimestamp() external view returns (uint64 lastRecomputedFundingTimestamp);

    function minExecutabilityAge() external view returns (uint64 minExecutabilityAge);

    function maxExecutabilityAge() external view returns (uint64 maxExecutabilityAge);

    function lastRecomputedFundingRate() external view returns (int256 lastRecomputedFundingRate);

    function cumulativeFundingRate() external view returns (int256 cumulativeFundingRate);

    function maxFundingVelocity() external view returns (uint256 maxFundingVelocity);

    function maxVelocitySkew() external view returns (uint256 maxVelocitySkew);

    function stableCollateralTotal() external view returns (uint256 totalAmount);

    function skewFractionMax() external view returns (uint256 skewFractionMax);

    function moduleAddress(bytes32 _moduleKey) external view returns (address moduleAddress);

    function isAuthorizedModule(address _address) external view returns (bool status);

    function isModulePaused(bytes32 moduleKey) external view returns (bool paused);

    function sendCollateral(address to, uint256 amount) external;

    function getVaultSummary() external view returns (FlatcoinStructs.VaultSummary memory _vaultSummary);

    function getGlobalPositions() external view returns (FlatcoinStructs.GlobalPositions memory _globalPositions);

    function setPosition(FlatcoinStructs.Position memory _position, uint256 _tokenId) external;

    function updateGlobalPositionData(uint256 price, int256 marginDelta, int256 additionalSizeDelta) external;

    function updateStableCollateralTotal(int256 _stableCollateralAdjustment) external;

    function addAuthorizedModules(FlatcoinStructs.AuthorizedModule[] calldata _modules) external;

    function addAuthorizedModule(FlatcoinStructs.AuthorizedModule calldata _module) external;

    function removeAuthorizedModule(bytes32 _moduleKey) external;

    function deletePosition(uint256 _tokenId) external;

    function settleFundingFees() external returns (int256 fundingFees);

    function getCurrentFundingRate() external view returns (int256 fundingRate);

    function getPosition(uint256 _tokenId) external view returns (FlatcoinStructs.Position memory position);

    function checkSkewMax(uint256 sizeChange, int256 stableCollateralChange) external view;

    function checkCollateralCap(uint256 depositAmount) external view;

    function stableCollateralCap() external view returns (uint256 collateralCap);

    function getCurrentSkew() external view returns (int256 skew);
}

// src/interfaces/IStableModule.sol

interface IStableModule is IERC20Metadata {
    function stableCollateralPerShare() external view returns (uint256 collateralPerShare);

    function executeDeposit(
        address account,
        uint64 executableAtTime,
        FlatcoinStructs.AnnouncedStableDeposit calldata announcedDeposit
    ) external returns (uint256 liquidityMinted);

    function executeWithdraw(
        address account,
        uint64 executableAtTime,
        FlatcoinStructs.AnnouncedStableWithdraw calldata announcedWithdraw
    ) external returns (uint256 amountOut, uint256 withdrawFee);

    function stableWithdrawFee() external view returns (uint256 stableWithdrawFee);

    function stableDepositQuote(uint256 depositAmount) external view returns (uint256 amountOut);

    function stableWithdrawQuote(uint256 withdrawAmount) external view returns (uint256 amountOut);

    function lock(address account, uint256 amount) external;

    function unlock(address account, uint256 amount) external;

    function getLockedAmount(address account) external view returns (uint256 amountLocked);
}

// src/libraries/PerpMath.sol

/// @title PerpMath
/// @author dHEDGE
/// @notice Abstract contract which contains necessary math functions for perps.
/// @dev Adapted from Synthetix PerpsV2MarketBase <https://github.com/Synthetixio/synthetix/blob/cbd8666f4331ee95fcc667ec7345d13c8ba77efb/contracts/PerpsV2MarketBase.sol#L156>
///      and <https://github.com/Synthetixio/synthetix/blob/cbd8666f4331ee95fcc667ec7345d13c8ba77efb/contracts/SafeDecimalMath.sol>
library PerpMath {
    using SignedMath for int256;
    using DecimalMath for int256;
    using DecimalMath for uint256;

    /////////////////////////////////////////////
    //           Funding Math Functions        //
    /////////////////////////////////////////////

    /// @dev Returns the pSkew = skew / skewScale capping the pSkew between [-1, 1].
    /// @param skew The current system skew.
    /// @param stableCollateralTotal The total stable collateral in the system.
    /// @return pSkew The capped proportional skew.
    function _proportionalSkew(int256 skew, uint256 stableCollateralTotal) internal pure returns (int256 pSkew) {
        if (stableCollateralTotal > 0) {
            pSkew = skew._divideDecimal(int256(stableCollateralTotal));

            if (pSkew < -1e18 || pSkew > 1e18) {
                pSkew = DecimalMath.UNIT.min(pSkew.max(-DecimalMath.UNIT));
            }
        } else {
            assert(skew == 0);
            pSkew = 0;
        }
    }

    /// @dev Retrieves the change in funding rate since the last re-computation.
    ///      There is no variance in computation but will be affected based on outside modifications to
    ///      the market skew, max funding velocity, and time delta.
    /// @param proportionalSkew The capped proportional skew.
    /// @param prevFundingModTimestamp The last recomputed funding timestamp.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    /// @return fundingChange The change in funding rate since the last re-computation.
    function _fundingChangeSinceRecomputed(
        int256 proportionalSkew,
        uint256 prevFundingModTimestamp,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew
    ) internal view returns (int256 fundingChange) {
        return
            _currentFundingVelocity(proportionalSkew, maxFundingVelocity, maxVelocitySkew)._multiplyDecimal(
                int256(_proportionalElapsedTime(prevFundingModTimestamp))
            );
    }

    /// @dev Function to calculate the funding rate based on market conditions.
    /// @param lastRecomputedFundingRate The last recomputed funding rate.
    /// @param lastRecomputedFundingTimestamp The last recomputed funding timestamp.
    /// @param proportionalSkew The capped proportional skew.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    /// @return currFundingRate The current funding rate.
    function _currentFundingRate(
        int256 lastRecomputedFundingRate,
        uint64 lastRecomputedFundingTimestamp,
        int256 proportionalSkew,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew
    ) internal view returns (int256 currFundingRate) {
        return
            lastRecomputedFundingRate +
            _fundingChangeSinceRecomputed(
                proportionalSkew,
                lastRecomputedFundingTimestamp,
                maxFundingVelocity,
                maxVelocitySkew
            );
    }

    /// @dev Calculates the sum of the unrecorded funding rates since the last funding re-computation.
    /// @param vaultSummary The current summary of the vault state.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    /// @return unrecordedFunding The sum of the unrecorded funding rates since the last funding re-computation.
    function _unrecordedFunding(
        FlatcoinStructs.VaultSummary memory vaultSummary,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew
    ) internal view returns (int256 unrecordedFunding) {
        int256 nextFundingRate = _currentFundingRate({
            proportionalSkew: _proportionalSkew(vaultSummary.marketSkew, vaultSummary.stableCollateralTotal),
            lastRecomputedFundingRate: vaultSummary.lastRecomputedFundingRate,
            lastRecomputedFundingTimestamp: vaultSummary.lastRecomputedFundingTimestamp,
            maxFundingVelocity: maxFundingVelocity,
            maxVelocitySkew: maxVelocitySkew
        });

        // NOTE: Synthetix uses the -ve sign here. We won't use it here as we believe it makes intutive sense
        // to use the same sign as the skew to preserve the traditional sense of the sign of the funding rate.
        // However, this also means that we have to invert the sign when calculating the difference between user's index
        // and the current global index for accumulated funding rate.
        int256 avgFundingRate = (vaultSummary.lastRecomputedFundingRate + nextFundingRate) / 2;
        return
            avgFundingRate._multiplyDecimal(
                int256(_proportionalElapsedTime(vaultSummary.lastRecomputedFundingTimestamp))
            );
    }

    /// @dev Same as the above `_unrecordedFunding but with the current funding rate passed in.
    /// @param currentFundingRate The current funding rate.
    /// @param prevFundingRate The previous funding rate.
    /// @param prevFundingModTimestamp The last recomputed funding timestamp.
    /// @return unrecordedFunding The sum of the unrecorded funding rates since the last funding re-computation.
    function _unrecordedFunding(
        int256 currentFundingRate,
        int256 prevFundingRate,
        uint256 prevFundingModTimestamp
    ) internal view returns (int256 unrecordedFunding) {
        int256 avgFundingRate = (prevFundingRate + currentFundingRate) / 2;

        return avgFundingRate._multiplyDecimal(int256(_proportionalElapsedTime(prevFundingModTimestamp)));
    }

    /// @dev The new entry in the funding sequence, appended when funding is recomputed.
    ///      It is the sum of the last entry and the unrecorded funding,
    ///      so the sequence accumulates running total over the market's lifetime.
    /// @param vaultSummary The current summary of the vault state.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    /// @return nextFundingEntry The next entry in the funding sequence.
    function _nextFundingEntry(
        FlatcoinStructs.VaultSummary memory vaultSummary,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew
    ) internal view returns (int256 nextFundingEntry) {
        return
            vaultSummary.cumulativeFundingRate + _unrecordedFunding(vaultSummary, maxFundingVelocity, maxVelocitySkew);
    }

    /// @dev Same as the above `_nextFundingEntry` but with the next funding entry passed in.
    /// @param unrecordedFunding The sum of the unrecorded funding rates since the last funding re-computation.
    /// @param latestFundingSequenceEntry The latest funding sequence entry.
    /// @return nextFundingEntry The next entry in the funding sequence.
    function _nextFundingEntry(
        int256 unrecordedFunding,
        int256 latestFundingSequenceEntry
    ) internal pure returns (int256 nextFundingEntry) {
        return latestFundingSequenceEntry + unrecordedFunding;
    }

    /// @dev Calculates the current net funding per unit for a position.
    /// @param userFundingSequenceEntry The user's last funding sequence entry.
    /// @param nextFundingEntry The next funding sequence entry.
    /// @return netFundingPerUnit The net funding per unit for a position.
    function _netFundingPerUnit(
        int256 userFundingSequenceEntry,
        int256 nextFundingEntry
    ) internal pure returns (int256 netFundingPerUnit) {
        return userFundingSequenceEntry - nextFundingEntry;
    }

    /*******************************************
     *             Position Details             *
     *******************************************/

    /// @dev Returns the PnL in terms of the market currency (ETH/LST) and not in dollars ($).
    ///      This function rounds down the PnL to avoid rounding errors when subtracting individual PnLs
    ///      from the global `marginDepositedTotal` value when closing the position.
    /// @param position The position to calculate the PnL for.
    /// @param price The current price of the collateral asset.
    /// @return pnl The PnL in terms of the market currency (ETH/LST) and not in dollars ($).
    function _profitLoss(FlatcoinStructs.Position memory position, uint256 price) internal pure returns (int256 pnl) {
        int256 priceShift = int256(price) - int256(position.averagePrice);
        int256 profitLossTimesTen = (int256(position.additionalSize) * (priceShift) * 10) / int256(price);

        if (profitLossTimesTen % 10 != 0) {
            return profitLossTimesTen / 10 - 1;
        } else {
            return profitLossTimesTen / 10;
        }
    }

    /// @dev Returns the PnL in terms of the market currency (ETH/LST) and not in dollars ($).
    ///      This function rounds down the funding accrued to avoid rounding errors when subtracting individual funding fees accrued
    ///      from the global `marginDepositedTotal` value when closing the position.
    /// @param globalPosition The global position to calculate the PnL for.
    /// @param price The current price of the collateral asset.
    /// @return pnl The PnL in terms of the market currency (ETH/LST) and not in dollars ($).
    function _profitLossTotal(
        FlatcoinStructs.GlobalPositions memory globalPosition,
        uint256 price
    ) internal pure returns (int256 pnl) {
        int256 priceShift = int256(price) - int256(globalPosition.averagePrice);

        return (int256(globalPosition.sizeOpenedTotal) * (priceShift)) / int256(price);
    }

    function _accruedFunding(
        FlatcoinStructs.Position memory position,
        int256 nextFundingEntry
    ) internal pure returns (int256 accruedFunding) {
        int256 net = _netFundingPerUnit(position.entryCumulativeFunding, nextFundingEntry);

        return int256(position.additionalSize)._multiplyDecimal(net);
    }

    /// @dev Calculates the funding fees accrued by the global position (all leverage traders).
    ///      To avoid rounding errors when individual positions close and the global `marginDepositedTotal` is updated,
    ///      we add 1 wei to the total accrued funding by longs. This also means that there might be some amount left in the
    ///      vault belonging to the longs which is not distributed. This is insignificant and is a trade-off to avoid rounding errors.
    /// @param globalPosition The global position to calculate the funding fees accrued for.
    /// @param unrecordedFunding The sum of the unrecorded funding rates since the last funding re-computation.
    /// @return accruedFundingLongs The funding fees accrued by the global position (all leverage traders).
    function _accruedFundingTotalByLongs(
        FlatcoinStructs.GlobalPositions memory globalPosition,
        int256 unrecordedFunding
    ) internal pure returns (int256 accruedFundingLongs) {
        int256 accruedFundingTotal = -int256(globalPosition.sizeOpenedTotal)._multiplyDecimal(unrecordedFunding);

        return (accruedFundingTotal != 0) ? accruedFundingTotal + 1 : accruedFundingTotal;
    }

    /// @dev Summarises a positions' earnings/losses.
    /// @param position The position to summarise.
    /// @param nextFundingEntry The next (recalculated) cumulative funding rate.
    /// @param price The current price of the collateral asset.
    /// @return positionSummary The summary of the position.
    function _getPositionSummary(
        FlatcoinStructs.Position memory position,
        int256 nextFundingEntry,
        uint256 price
    ) internal pure returns (FlatcoinStructs.PositionSummary memory positionSummary) {
        int256 profitLoss = _profitLoss(position, price);
        int256 accruedFunding = _accruedFunding(position, nextFundingEntry);

        return
            FlatcoinStructs.PositionSummary({
                profitLoss: profitLoss,
                accruedFunding: accruedFunding,
                marginAfterSettlement: int256(position.marginDeposited) + profitLoss + accruedFunding
            });
    }

    /// @dev Summarises the market state which is used in other functions.
    /// @param vaultSummary The current summary of the vault state.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    /// @param price The current price of the collateral asset.
    /// @return marketSummary The summary of the market.
    function _getMarketSummaryLongs(
        FlatcoinStructs.VaultSummary memory vaultSummary,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew,
        uint256 price
    ) internal view returns (FlatcoinStructs.MarketSummary memory marketSummary) {
        int256 currentFundingRate = _currentFundingRate({
            proportionalSkew: _proportionalSkew(vaultSummary.marketSkew, vaultSummary.stableCollateralTotal),
            lastRecomputedFundingRate: vaultSummary.lastRecomputedFundingRate,
            lastRecomputedFundingTimestamp: vaultSummary.lastRecomputedFundingTimestamp,
            maxFundingVelocity: maxFundingVelocity,
            maxVelocitySkew: maxVelocitySkew
        });

        int256 unrecordedFunding = _unrecordedFunding(
            currentFundingRate,
            vaultSummary.lastRecomputedFundingRate,
            vaultSummary.lastRecomputedFundingTimestamp
        );

        return
            FlatcoinStructs.MarketSummary({
                profitLossTotalByLongs: _profitLossTotal(vaultSummary.globalPositions, price),
                accruedFundingTotalByLongs: _accruedFundingTotalByLongs(
                    vaultSummary.globalPositions,
                    unrecordedFunding
                ),
                currentFundingRate: currentFundingRate,
                nextFundingEntry: _nextFundingEntry(unrecordedFunding, vaultSummary.cumulativeFundingRate)
            });
    }

    /////////////////////////////////////////////
    //            Liquidation Math             //
    /////////////////////////////////////////////

    /// @notice Function to calculate the approximate liquidation price.
    /// @dev Only approximation can be achieved due to the fact that the funding rate influences the liquidation price.
    /// @param position The position to calculate the liquidation price for.
    /// @param nextFundingEntry The next (recalculated) cumulative funding rate.
    /// @param liquidationFeeRatio The liquidation fee of the system.
    /// @param liquidationBufferRatio The liquidation buffer ratio of the system.
    /// @param liquidationFeeUpperBound The maximum liquidation fee to be paid to the keepers.
    /// @param currentPrice Current price of the collateral asset.
    function _approxLiquidationPrice(
        FlatcoinStructs.Position memory position,
        int256 nextFundingEntry,
        uint128 liquidationFeeRatio,
        uint128 liquidationBufferRatio,
        uint256 liquidationFeeLowerBound,
        uint256 liquidationFeeUpperBound,
        uint256 currentPrice
    ) internal pure returns (uint256 approxLiquidationPrice) {
        if (position.additionalSize == 0) {
            return 0;
        }

        FlatcoinStructs.PositionSummary memory positionSummary = _getPositionSummary(
            position,
            nextFundingEntry,
            currentPrice
        );

        int256 result = _calcLiquidationPrice(
            position,
            positionSummary,
            _liquidationMargin(
                position.additionalSize,
                liquidationFeeRatio,
                liquidationBufferRatio,
                liquidationFeeLowerBound,
                liquidationFeeUpperBound,
                currentPrice
            )
        );

        return (result > 0) ? uint256(result) : 0;
    }

    /// @dev Function to get the liquidation status of a position.
    /// @param position The position to check the liquidation status for.
    /// @param liquidationFeeRatio The liquidation fee of the system.
    /// @param liquidationBufferRatio The liquidation buffer ratio of the system.
    /// @param liquidationFeeLowerBound The minimum liquidation fee to be paid to the flagger.
    /// @param liquidationFeeUpperBound The maximum liquidation fee to be paid to the keepers.
    /// @param nextFundingEntry The next (recalculated) cumulative funding rate.
    /// @param currentPrice Current price of the collateral asset.
    /// @return isLiquidatable Whether the position is liquidatable.
    function _canLiquidate(
        FlatcoinStructs.Position memory position,
        uint128 liquidationFeeRatio,
        uint128 liquidationBufferRatio,
        uint256 liquidationFeeLowerBound,
        uint256 liquidationFeeUpperBound,
        int256 nextFundingEntry,
        uint256 currentPrice
    ) internal pure returns (bool isLiquidatable) {
        // No liquidations of empty positions.
        if (position.additionalSize == 0) {
            return false;
        }

        FlatcoinStructs.PositionSummary memory positionSummary = _getPositionSummary(
            position,
            nextFundingEntry,
            currentPrice
        );

        uint256 lMargin = _liquidationMargin(
            position.additionalSize,
            liquidationFeeRatio,
            liquidationBufferRatio,
            liquidationFeeLowerBound,
            liquidationFeeUpperBound,
            currentPrice
        );

        return positionSummary.marginAfterSettlement <= int256(lMargin);
    }

    /// @dev The minimal margin at which liquidation can happen.
    ///      Is the sum of liquidationBuffer, liquidationFee (for flagger) and keeperLiquidationFee (for liquidator)
    ///      The liquidation margin contains a buffer that is proportional to the position
    ///      size. The buffer should prevent liquidation happening at negative margin (due to next price being worse).
    /// @param positionSize size of position in fixed point decimal collateral asset units.
    /// @param liquidationFeeRatio ratio of the position size to be charged as fee.
    /// @param liquidationBufferRatio ratio of the position size needed to be maintained as buffer.
    /// @param liquidationFeeUpperBound maximum fee to be charged in collateral asset units.
    /// @param currentPrice current price of the collateral asset in USD units.
    /// @return lMargin liquidation margin to maintain in collateral asset units.
    function _liquidationMargin(
        uint256 positionSize,
        uint128 liquidationFeeRatio,
        uint128 liquidationBufferRatio,
        uint256 liquidationFeeLowerBound,
        uint256 liquidationFeeUpperBound,
        uint256 currentPrice
    ) internal pure returns (uint256 lMargin) {
        uint256 liquidationBuffer = positionSize._multiplyDecimal(liquidationBufferRatio);

        // The liquidation margin consists of the liquidation buffer, liquidation fee and the keeper fee for covering execution costs.
        return
            liquidationBuffer +
            _liquidationFee(
                positionSize,
                liquidationFeeRatio,
                liquidationFeeLowerBound,
                liquidationFeeUpperBound,
                currentPrice
            );
    }

    /// The fee charged from the margin during liquidation. Fee is proportional to position size.
    /// @dev There is a cap on the fee to prevent liquidators from being overpayed.
    /// @param positionSize size of position in fixed point decimal baseAsset units.
    /// @param liquidationFeeRatio ratio of the position size to be charged as fee.
    /// @param liquidationFeeUpperBound maximum fee to be charged in USD units.
    /// @return liquidationFee liquidation fee to be paid to liquidator in collateral asset units.
    function _liquidationFee(
        uint256 positionSize,
        uint128 liquidationFeeRatio,
        uint256 liquidationFeeLowerBound,
        uint256 liquidationFeeUpperBound,
        uint256 currentPrice
    ) internal pure returns (uint256 liquidationFee) {
        // size * price * fee-ratio
        uint256 proportionalFee = positionSize._multiplyDecimal(liquidationFeeRatio)._multiplyDecimal(currentPrice);
        uint256 cappedProportionalFee = proportionalFee > liquidationFeeUpperBound
            ? liquidationFeeUpperBound
            : proportionalFee;

        uint256 lFeeUSD = cappedProportionalFee < liquidationFeeLowerBound
            ? liquidationFeeLowerBound
            : cappedProportionalFee;

        // Return liquidation fee in collateral asset units.
        return (lFeeUSD * 1e18) / currentPrice;
    }

    /////////////////////////////////////////////
    //            Private Functions            //
    /////////////////////////////////////////////

    /// @dev The funding velocity is based on the market skew and is scaled by the maxVelocitySkew.
    ///      With higher skews beyond the maxVelocitySkew, the velocity remains constant.
    /// @param proportionalSkew The calculated capped proportional skew.
    /// @param maxFundingVelocity The maximum funding velocity.
    /// @param maxVelocitySkew The maximum velocity skew.
    function _currentFundingVelocity(
        int256 proportionalSkew,
        uint256 maxFundingVelocity,
        uint256 maxVelocitySkew
    ) private pure returns (int256 currFundingVelocity) {
        if (maxVelocitySkew > 0) {
            // Scale the funding velocity by the maxVelocitySkew and cap it at the maximum +- velocity.
            int256 fundingVelocity = (proportionalSkew * int256(maxFundingVelocity)) / int256(maxVelocitySkew);
            return int256(maxFundingVelocity).min(fundingVelocity.max(-int256(maxFundingVelocity)));
        }

        return proportionalSkew._multiplyDecimal(int256(maxFundingVelocity));
    }

    /// @dev Returns the time delta between the last funding timestamp and the current timestamp.
    /// @param prevModTimestamp The last funding timestamp.
    /// @return elapsedTime The time delta between the last funding timestamp and the current timestamp.
    function _proportionalElapsedTime(uint256 prevModTimestamp) private view returns (uint256 elapsedTime) {
        return (block.timestamp - prevModTimestamp)._divideDecimal(1 days);
    }

    /// @dev Calculates the liquidation price.
    /// @param position The position to calculate the liquidation price for.
    /// @param positionSummary The summary of the position.
    /// @param liquidationMargin The liquidation margin.
    /// @return liqPrice The liquidation price.
    function _calcLiquidationPrice(
        FlatcoinStructs.Position memory position,
        FlatcoinStructs.PositionSummary memory positionSummary,
        uint256 liquidationMargin
    ) private pure returns (int256 liqPrice) {
        // A position can be liquidated whenever:- remainingMargin <= liquidationMargin
        //
        // Hence, expanding the definition of remainingMargin the exact price at which a position can be liquidated is:
        //
        // liquidationMargin = margin + profitLoss + funding
        // liquidationMargin = margin + [(price - entryPrice) * postionSize / price] + funding
        // liquidationMargin - (margin + funding) = [(price - entryPrice) * postionSize / price]
        // liquidationMargin - (margin + funding) = postionSize - (entryPrice * postionSize / price)
        // positionSize - [liquidationMargin - (margin + funding)] = entryPrice * postionSize / price
        // positionSize * entryPrice / {positionSize - [liquidationMargin - (margin + funding)]} = price
        //
        // In our case, positionSize = position.additionalSize.
        // Note: If there are bounds on `liquidationFee` and/or `keeperFee` then this formula doesn't yield an accurate liquidation price.
        // This is because, when the position size is too large such that liquidation fee for that position has to be bounded we are essentially
        // solving the following equation:
        // LiquidationBuffer + (LiquidationUpperBound / Price) + KeeperFee = Margin + (Price - EntryPrice)*PositionSize + AccruedFunding
        // And according to Wolfram Alpha, this equation cannot be solved for Price (at least trivially):
        // https://www.wolframalpha.com/input?i=A+++(B+/+X)+%3D+C+++(X+-+D)+*+E+,+X+%3E+0,+Solution+for+variable+X
        return
            int256((position.additionalSize)._multiplyDecimal(position.averagePrice))._divideDecimal(
                int256(position.additionalSize + position.marginDeposited) +
                    positionSummary.accruedFunding -
                    int256(liquidationMargin)
            );
    }
}

// src/interfaces/ILeverageModule.sol

interface ILeverageModule is IERC721Enumerable {
    function executeOpen(
        address account,
        address keeper,
        FlatcoinStructs.Order calldata order
    ) external returns (uint256 newTokenId);

    function executeAdjust(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function executeClose(
        address account,
        address keeper,
        FlatcoinStructs.Order calldata order
    ) external returns (int256 settledMargin);

    function burn(uint256 tokenId, bytes32 moduleKey) external;

    function lock(uint256 tokenId, bytes32 moduleKey) external;

    function unlock(uint256 tokenId, bytes32 moduleKey) external;

    function isLocked(uint256 tokenId) external view returns (bool lockStatus);

    function isLockedByModule(uint256 _tokenId, bytes32 _moduleKey) external view returns (bool _lockedByModuleStatus);

    function getPositionSummary(
        uint256 tokenId
    ) external view returns (FlatcoinStructs.PositionSummary memory positionSummary);

    function fundingAdjustedLongPnLTotal() external view returns (int256 _fundingAdjustedPnL);

    function fundingAdjustedLongPnLTotal(
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (int256 _fundingAdjustedPnL);

    function tokenIdNext() external view returns (uint256 tokenId);

    function leverageTradingFee() external view returns (uint256 leverageTradingFee);

    function checkLeverageCriteria(uint256 margin, uint256 size) external view;

    function marginMin() external view returns (uint256 marginMin);

    function getTradeFee(uint256 size) external view returns (uint256 tradeFee);
}

// src/abstracts/OracleModifiers.sol

/// @title OracleModifiers
abstract contract OracleModifiers {
    /// @dev Important to use this modifier in functions which require the Pyth network price to be updated.
    ///      Otherwise, the invariant checks or any other logic which depends on the Pyth network price may not be correct.
    modifier updatePythPrice(
        IFlatcoinVault vault,
        address sender,
        bytes[] calldata priceUpdateData
    ) {
        IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).updatePythPrice{value: msg.value}(
            sender,
            priceUpdateData
        );
        _;
    }
}

// src/abstracts/ModuleUpgradeable.sol

/// @title ModuleUpgradeable
/// @author dHEDGE
/// @notice This is the base contract for all upgradeable modules in the Flatcoin system.
abstract contract ModuleUpgradeable is Initializable {
    /// @notice The bytes32 encoded key of the module.
    /// @dev Note that this shouldn't change ever for existing modules.
    ///      Due to this module being upgradeable, we can't use immutable here.
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public MODULE_KEY;

    /// @notice The FlatcoinVault contract referred to by all modules.
    /// @dev Contains all the module addresses, the state of the system and more.
    IFlatcoinVault public vault;

    modifier onlyAuthorizedModule() {
        if (vault.isAuthorizedModule(msg.sender) == false) revert FlatcoinErrors.OnlyAuthorizedModule(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (vault.isModulePaused(MODULE_KEY)) revert FlatcoinErrors.Paused(MODULE_KEY);
        _;
    }

    modifier onlyOwner() {
        if (OwnableUpgradeable(address(vault)).owner() != msg.sender) revert FlatcoinErrors.OnlyOwner(msg.sender);
        _;
    }

    /// @notice Setter for the vault contract.
    /// @dev Can be used in case FlatcoinVault ever changes.
    function setVault(IFlatcoinVault _vault) external onlyOwner {
        if (address(_vault) == address(0)) revert FlatcoinErrors.ZeroAddress("vault");

        vault = _vault;
    }

    /// @dev Function to initialize a module.
    /// @param _moduleKey The bytes32 encoded key of the module.
    /// @param _vault FlatcoinVault contract address.
    // solhint-disable-next-line func-name-mixedcase
    function __Module_init(bytes32 _moduleKey, IFlatcoinVault _vault) internal {
        if (_moduleKey == bytes32("")) revert FlatcoinErrors.ModuleKeyEmpty();
        if (address(_vault) == address(0)) revert FlatcoinErrors.ZeroAddress("vault");

        MODULE_KEY = _moduleKey;
        vault = _vault;
    }

    uint256[48] private __gap;
}

// src/misc/InvariantChecks.sol

/// @title InvariantChecks
/// @author dHEDGE
/// @notice Contract module for critical invariant checking on the protocol.
abstract contract InvariantChecks {
    struct InvariantOrder {
        int256 collateralNet;
        uint256 stableCollateralPerShare;
    }

    struct InvariantLiquidation {
        int256 collateralNet;
        uint256 stableCollateralPerShare;
        int256 remainingMargin;
        uint256 liquidationFee;
    }

    /// @notice Invariant checks on order execution
    /// @dev Checks:
    ///      1. Collateral net: The vault collateral balance relative to tracked collateral on both stable LP and leverage side should not change
    ///      2. Stable collateral per share: Stable LP value per share should never decrease after order execution. It should only increase due to collected trading fees
    modifier orderInvariantChecks(IFlatcoinVault vault) {
        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantOrder memory invariantBefore = InvariantOrder({ // helps with stack too deep
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        _;

        InvariantOrder memory invariantAfter = InvariantOrder({
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        _collateralNetBalanceRemainsUnchanged(invariantBefore.collateralNet, invariantAfter.collateralNet);
        _stableCollateralPerShareIncreasesOrRemainsUnchanged(
            stableModule.totalSupply(),
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );
        _globalAveragePriceIsNotNegative(vault);
    }

    /// @notice Invariant checks on order liquidation
    /// @dev For liquidations, stableCollateralPerShare can decrease if the position is underwater.
    modifier liquidationInvariantChecks(IFlatcoinVault vault, uint256 tokenId) {
        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantLiquidation memory invariantBefore = InvariantLiquidation({ // helps with stack too deep
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY))
                .getPositionSummary(tokenId)
                .marginAfterSettlement,
            liquidationFee: ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY))
                .getLiquidationFee(tokenId)
        });

        _;

        InvariantLiquidation memory invariantAfter = InvariantLiquidation({
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: 0, // not used
            liquidationFee: 0 // not used
        });

        _stableCollateralPerShareLiquidation(
            stableModule,
            invariantBefore.liquidationFee,
            invariantBefore.remainingMargin,
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );

        _collateralNetBalanceRemainsUnchanged(invariantBefore.collateralNet, invariantAfter.collateralNet);
        _globalAveragePriceIsNotNegative(vault);
    }

    /// @dev Returns the difference between actual total collateral balance in the vault vs tracked collateral
    ///      Tracked collateral should be updated when depositing to stable LP (stableCollateralTotal) or
    ///      opening leveraged positions (marginDepositedTotal).
    function _getCollateralNet(IFlatcoinVault vault) private view returns (int256 netCollateral) {
        int256 collateralBalance = int256(vault.collateral().balanceOf(address(vault)));
        int256 trackedCollateral = int256(vault.stableCollateralTotal()) +
            vault.getGlobalPositions().marginDepositedTotal;

        if (collateralBalance < trackedCollateral) revert FlatcoinErrors.InvariantViolation("collateralNet1");

        return collateralBalance - trackedCollateral;
    }

    function _globalAveragePriceIsNotNegative(IFlatcoinVault vault) private view {
        if (vault.getGlobalPositions().averagePrice < 0)
            revert FlatcoinErrors.InvariantViolation("globalAveragePriceIsNotNegative");
    }

    /// @dev Collateral balance changes should match tracked collateral changes
    function _collateralNetBalanceRemainsUnchanged(int256 netBefore, int256 netAfter) private pure {
        // Note: +1e6 to account for rounding errors.
        // This means we are ok with a small margin of error such that netAfter - 1e6 <= netBefore <= netAfter.
        if (netBefore > netAfter || netAfter > netBefore + 1e6)
            revert FlatcoinErrors.InvariantViolation("collateralNet2");
    }

    /// @dev Stable LPs should never lose value (can only gain on trading fees)
    function _stableCollateralPerShareIncreasesOrRemainsUnchanged(
        uint256 totalSupply,
        uint256 collateralPerShareBefore,
        uint256 collateralPerShareAfter
    ) private pure {
        // Note: +1 to account for rounding error
        if (totalSupply > 0 && collateralPerShareAfter + 1 < collateralPerShareBefore)
            revert FlatcoinErrors.InvariantViolation("stableCollateralPerShare");
    }

    /// @dev Stable LPs should be adjusted according to the liquidated position remaining margin and liquidation fee
    function _stableCollateralPerShareLiquidation(
        IStableModule stableModule,
        uint256 liquidationFee,
        int256 remainingMargin,
        uint256 stableCollateralPerShareBefore,
        uint256 stableCollateralPerShareAfter
    ) private view {
        uint256 totalSupply = stableModule.totalSupply();

        if (totalSupply == 0) return;

        int256 expectedStableCollateralPerShare;
        if (remainingMargin > 0) {
            if (remainingMargin > int256(liquidationFee)) {
                // position is healthy and there is a keeper fee taken from the margin
                // evaluate exact increase in stable collateral
                expectedStableCollateralPerShare =
                    int256(stableCollateralPerShareBefore) +
                    (((remainingMargin - int256(liquidationFee)) * 1e18) / int256(stableModule.totalSupply()));
            } else {
                // position has less or equal margin than liquidation fee
                // all the margin will go to the keeper and no change in stable collateral
                if (stableCollateralPerShareBefore != stableCollateralPerShareAfter)
                    revert FlatcoinErrors.InvariantViolation("stableCollateralPerShareLiquidation");

                return;
            }
        } else {
            // position is underwater and there is no keeper fee
            // evaluate exact decrease in stable collateral
            expectedStableCollateralPerShare =
                int256(stableCollateralPerShareBefore) +
                ((remainingMargin * 1e18) / int256(stableModule.totalSupply())); // underwater margin per share
        }
        if (
            expectedStableCollateralPerShare + 1e6 < int256(stableCollateralPerShareAfter) || // rounding error
            expectedStableCollateralPerShare - 1e6 > int256(stableCollateralPerShareAfter)
        ) revert FlatcoinErrors.InvariantViolation("stableCollateralPerShareLiquidation");
    }
}

// src/LiquidationModule.sol

/// @title LiquidationModule
/// @author dHEDGE
/// @notice Module for liquidating leveraged positions.
contract LiquidationModule is
    ILiquidationModule,
    ModuleUpgradeable,
    OracleModifiers,
    ReentrancyGuardUpgradeable,
    InvariantChecks
{
    /// @notice Liquidation fee basis points paid to liquidator.
    /// @dev Note that this needs to be used together with keeper fee bounds.
    /// @dev Should include 18 decimals i.e, 0.2% => 0.002e18 => 2e15
    uint128 public liquidationFeeRatio;

    /// @notice Liquidation price buffer in basis points to prevent negative margin on liquidation.
    /// @dev Should include 18 decimals i.e, 0.75% => 0.0075e18 => 75e14
    uint128 public liquidationBufferRatio;

    /// @notice Upper bound for the liquidation fee.
    /// @dev Denominated in USD.
    uint256 public liquidationFeeUpperBound;

    /// @notice Lower bound for the liquidation fee.
    /// @dev Denominated in USD.
    uint256 public liquidationFeeLowerBound;

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IFlatcoinVault _vault,
        uint128 _liquidationFeeRatio,
        uint128 _liquidationBufferRatio,
        uint256 _liquidationFeeLowerBound,
        uint256 _liquidationFeeUpperBound
    ) external initializer {
        __Module_init(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY, _vault);
        __ReentrancyGuard_init();

        setLiquidationFeeRatio(_liquidationFeeRatio);
        setLiquidationBufferRatio(_liquidationBufferRatio);
        setLiquidationFeeBounds(_liquidationFeeLowerBound, _liquidationFeeUpperBound);
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    function liquidate(
        uint256 tokenID,
        bytes[] calldata priceUpdateData
    ) external payable updatePythPrice(vault, msg.sender, priceUpdateData) {
        liquidate(tokenID);
    }

    /// @notice Function to liquidate a position.
    /// @dev One could directly call this method instead of `liquidate(uint256, bytes[])` if they don't want to update the Pyth price.
    /// @param tokenId The token ID of the leverage position.
    function liquidate(uint256 tokenId) public nonReentrant whenNotPaused liquidationInvariantChecks(vault, tokenId) {
        FlatcoinStructs.Position memory position = vault.getPosition(tokenId);

        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            maxAge: 86_400,
            priceDiffCheck: true
        });

        // Settle funding fees accrued till now.
        vault.settleFundingFees();

        // Check if the position can indeed be liquidated.
        if (!canLiquidate(tokenId)) revert FlatcoinErrors.CannotLiquidate(tokenId);

        FlatcoinStructs.PositionSummary memory positionSummary = PerpMath._getPositionSummary(
            position,
            vault.cumulativeFundingRate(),
            currentPrice
        );

        // Check that the total margin deposited by the long traders is not -ve.
        // To get this amount, we will have to account for the PnL and funding fees accrued.
        int256 settledMargin = positionSummary.marginAfterSettlement;

        uint256 liquidatorFee;

        // If the settled margin is greater than 0, send a portion (or all) of the margin to the liquidator and LPs.
        if (settledMargin > 0) {
            // Calculate the liquidation fees to be sent to the caller.
            uint256 expectedLiquidationFee = PerpMath._liquidationFee(
                position.additionalSize,
                liquidationFeeRatio,
                liquidationFeeLowerBound,
                liquidationFeeUpperBound,
                currentPrice
            );

            int256 remainingMargin;

            // Calculate the remaining margin after accounting for liquidation fees.
            // If the settled margin is less than the liquidation fee, then the liquidator fee is the settled margin.
            if (uint256(settledMargin) > expectedLiquidationFee) {
                liquidatorFee = expectedLiquidationFee;
                remainingMargin = settledMargin - int256(expectedLiquidationFee);
            } else {
                liquidatorFee = uint256(settledMargin);
            }

            // Adjust the stable collateral total to account for user's remaining margin (accounts for liquidation fee).
            // If the remaining margin is greater than 0, this goes to the LPs.
            // Note that {`remainingMargin` - `profitLoss`} is the same as {`marginDeposited` + `accruedFunding` - `liquidationFee`}.
            // This means, the margin associated with the position plus the funding that's been settled should go to the LPs
            // after adjusting for the liquidation fee.
            vault.updateStableCollateralTotal(remainingMargin - positionSummary.profitLoss);

            // Send the liquidator fee to the caller of the function.
            // If the liquidation fee is greater than the remaining margin, then send the remaining margin.
            vault.sendCollateral(msg.sender, liquidatorFee);
        } else {
            // If the settled margin is -ve then the LPs have to bear the cost.
            // Adjust the stable collateral total to account for user's negative remaining margin (includes PnL).
            // Note: The following is similar to giving the margin and the settled funding fees associated with the position to the LPs.
            vault.updateStableCollateralTotal(settledMargin - positionSummary.profitLoss);
        }

        // Update the global leverage position data.
        vault.updateGlobalPositionData({
            price: position.averagePrice,
            marginDelta: -(int256(position.marginDeposited) + positionSummary.accruedFunding),
            additionalSizeDelta: -int256(position.additionalSize) // Since position is being closed, additionalSizeDelta should be negative.
        });

        // Delete position storage
        vault.deletePosition(tokenId);

        // Cancel any limit orders associated with the position
        ILimitOrder(vault.moduleAddress(FlatcoinModuleKeys._LIMIT_ORDER_KEY)).cancelExistingLimitOrder(tokenId);

        // If the position token is locked because of an announced order, it should still be liquidatable
        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        leverageModule.burn(tokenId, FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY);

        emit FlatcoinEvents.PositionLiquidated(tokenId, msg.sender, liquidatorFee, currentPrice, positionSummary);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Function to calculate liquidation price for a given position.
    /// @dev Note that liquidation price is influenced by the funding rates and also the current price.
    /// @param tokenId The token ID of the leverage position.
    /// @return liqPrice The liquidation price in $ terms.
    function liquidationPrice(uint256 tokenId) public view returns (uint256 liqPrice) {
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        return liquidationPrice(tokenId, currentPrice);
    }

    /// @notice Function to calculate liquidation price for a given position at a given price.
    /// @dev Note that liquidation price is influenced by the funding rates and also the current price.
    /// @param tokenId The token ID of the leverage position.
    /// @param price The price at which the liquidation price is to be calculated.
    /// @return liqPrice The liquidation price in $ terms.
    function liquidationPrice(uint256 tokenId, uint256 price) public view returns (uint256 liqPrice) {
        FlatcoinStructs.Position memory position = vault.getPosition(tokenId);

        int256 nextFundingEntry = _accountFundingFees();

        return
            PerpMath._approxLiquidationPrice({
                position: position,
                nextFundingEntry: nextFundingEntry,
                liquidationFeeRatio: liquidationFeeRatio,
                liquidationBufferRatio: liquidationBufferRatio,
                liquidationFeeLowerBound: liquidationFeeLowerBound,
                liquidationFeeUpperBound: liquidationFeeUpperBound,
                currentPrice: price
            });
    }

    /// @notice Function which determines if a leverage position can be liquidated or not.
    /// @param tokenId The token ID of the leverage position.
    /// @return liquidatable True if the position can be liquidated, false otherwise.
    function canLiquidate(uint256 tokenId) public view returns (bool liquidatable) {
        // Get the current price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        return canLiquidate(tokenId, currentPrice);
    }

    function canLiquidate(uint256 tokenId, uint256 price) public view returns (bool liquidatable) {
        FlatcoinStructs.Position memory position = vault.getPosition(tokenId);

        int256 nextFundingEntry = _accountFundingFees();

        return
            PerpMath._canLiquidate({
                position: position,
                liquidationFeeRatio: liquidationFeeRatio,
                liquidationBufferRatio: liquidationBufferRatio,
                liquidationFeeLowerBound: liquidationFeeLowerBound,
                liquidationFeeUpperBound: liquidationFeeUpperBound,
                nextFundingEntry: nextFundingEntry,
                currentPrice: price
            });
    }

    /// @notice Function to calculate the liquidation fee awarded for a liquidating a given position.
    /// @param tokenId The token ID of the leverage position.
    /// @return liquidationFee The liquidation fee in collateral units.
    function getLiquidationFee(uint256 tokenId) public view returns (uint256 liquidationFee) {
        // Get the latest price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        return
            PerpMath._liquidationFee(
                vault.getPosition(tokenId).additionalSize,
                liquidationFeeRatio,
                liquidationFeeLowerBound,
                liquidationFeeUpperBound,
                currentPrice
            );
    }

    /// @notice Function to calculate the liquidation margin for a given additional size amount.
    /// @param additionalSize The additional size amount for which the liquidation margin is to be calculated.
    /// @return liquidationMargin The liquidation margin in collateral units.
    function getLiquidationMargin(uint256 additionalSize) public view returns (uint256 liquidationMargin) {
        // Get the latest price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        return getLiquidationMargin(additionalSize, currentPrice);
    }

    /// @notice Function to calculate the liquidation margin for a given additional size amount and price.
    /// @param additionalSize The additional size amount for which the liquidation margin is to be calculated.
    /// @param price The price at which the liquidation margin is to be calculated.
    /// @return liquidationMargin The liquidation margin in collateral units.
    function getLiquidationMargin(
        uint256 additionalSize,
        uint256 price
    ) public view returns (uint256 liquidationMargin) {
        return
            PerpMath._liquidationMargin(
                additionalSize,
                liquidationFeeRatio,
                liquidationBufferRatio,
                liquidationFeeLowerBound,
                liquidationFeeUpperBound,
                price
            );
    }

    /////////////////////////////////////////////
    //            Owner Functions              //
    /////////////////////////////////////////////

    function setLiquidationFeeRatio(uint128 _newLiquidationFeeRatio) public onlyOwner {
        if (_newLiquidationFeeRatio == 0) revert FlatcoinErrors.ZeroValue("newLiquidationFeeRatio");

        emit FlatcoinEvents.LiquidationFeeRatioModified(liquidationFeeRatio, _newLiquidationFeeRatio);

        liquidationFeeRatio = _newLiquidationFeeRatio;
    }

    function setLiquidationBufferRatio(uint128 _newLiquidationBufferRatio) public onlyOwner {
        if (_newLiquidationBufferRatio == 0) revert FlatcoinErrors.ZeroValue("newLiquidationBufferRatio");

        emit FlatcoinEvents.LiquidationBufferRatioModified(liquidationBufferRatio, _newLiquidationBufferRatio);

        liquidationBufferRatio = _newLiquidationBufferRatio;
    }

    function setLiquidationFeeBounds(
        uint256 _newLiquidationFeeLowerBound,
        uint256 _newLiquidationFeeUpperBound
    ) public onlyOwner {
        if (_newLiquidationFeeUpperBound == 0 || _newLiquidationFeeLowerBound == 0)
            revert FlatcoinErrors.ZeroValue("newLiquidationFee");
        if (_newLiquidationFeeUpperBound < _newLiquidationFeeLowerBound)
            revert FlatcoinErrors.InvalidBounds(_newLiquidationFeeLowerBound, _newLiquidationFeeUpperBound);

        emit FlatcoinEvents.LiquidationFeeBoundsModified(
            liquidationFeeLowerBound,
            liquidationFeeUpperBound,
            _newLiquidationFeeLowerBound,
            _newLiquidationFeeUpperBound
        );

        liquidationFeeLowerBound = _newLiquidationFeeLowerBound;
        liquidationFeeUpperBound = _newLiquidationFeeUpperBound;
    }

    /////////////////////////////////////////////
    //           Internal Functions            //
    /////////////////////////////////////////////

    /// @dev Accounts for the funding fees based on the market state.
    /// @return nextFundingEntry The cumulative funding rate based on the latest market state.
    function _accountFundingFees() internal view returns (int256 nextFundingEntry) {
        uint256 stableCollateralTotal = vault.stableCollateralTotal();
        int256 currMarketSkew = int256(vault.getGlobalPositions().sizeOpenedTotal) - int256(stableCollateralTotal);

        int256 currentFundingRate = PerpMath._currentFundingRate({
            proportionalSkew: PerpMath._proportionalSkew({
                skew: currMarketSkew,
                stableCollateralTotal: stableCollateralTotal
            }),
            lastRecomputedFundingRate: vault.lastRecomputedFundingRate(),
            lastRecomputedFundingTimestamp: vault.lastRecomputedFundingTimestamp(),
            maxFundingVelocity: vault.maxFundingVelocity(),
            maxVelocitySkew: vault.maxVelocitySkew()
        });

        int256 unrecordedFunding = PerpMath._unrecordedFunding(
            currentFundingRate,
            vault.lastRecomputedFundingRate(),
            vault.lastRecomputedFundingTimestamp()
        );

        return PerpMath._nextFundingEntry(unrecordedFunding, vault.cumulativeFundingRate());
    }
}
