// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity =0.8.28 ^0.8.20 ^0.8.28;

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// src/interfaces/structs/DelayedOrderStructs.sol

enum OrderType {
    None, // 0
    StableDeposit, // 1
    StableWithdraw, // 2
    LeverageOpen, // 3
    LeverageClose, // 4
    LeverageAdjust, // 5
    LimitClose // 6
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
    address announcedBy; // To differentiate between deposit and depositFor
}

struct AnnouncedStableWithdraw {
    uint256 withdrawAmount;
    uint256 minAmountOut; // The minimum amount of underlying tokens expected to receive back
}

struct AnnouncedLeverageOpen {
    uint256 margin; // The margin amount to be used as leverage collateral
    uint256 additionalSize; // The additional size exposure (leverage)
    uint256 maxFillPrice; // The maximum price accepted by the user
    uint256 stopLossPrice; // The price lower threshold for the limit order
    uint256 profitTakePrice; // The price upper threshold for the limit order
    uint256 tradeFee;
    address announcedBy; // To differentiate between open and openFor
}

struct AnnouncedLeverageAdjust {
    uint256 tokenId;
    int256 marginAdjustment;
    int256 additionalSizeAdjustment;
    uint256 fillPrice; // should be passed depending on the type of additionalSizeAdjustment
    uint256 tradeFee;
    uint256 totalFee;
}

struct AnnouncedLeverageClose {
    uint256 tokenId; // The NFT of the position
    uint256 minFillPrice; // The minimum price accepted by the user
    uint256 tradeFee;
}

struct AnnouncedLimitClose {
    uint256 tokenId;
    uint256 stopLossPrice;
    uint256 profitTakePrice;
}

// src/libraries/FlatcoinModuleKeys.sol

library FlatcoinModuleKeys {
    bytes32 internal constant _STABLE_MODULE_KEY = bytes32("stableModule");
    bytes32 internal constant _LEVERAGE_MODULE_KEY = bytes32("leverageModule");
    bytes32 internal constant _ORACLE_MODULE_KEY = bytes32("oracleModule");
    bytes32 internal constant _ORDER_ANNOUNCEMENT_MODULE_KEY = bytes32("orderAnnouncementModule");
    bytes32 internal constant _ORDER_EXECUTION_MODULE_KEY = bytes32("orderExecutionModule");
    bytes32 internal constant _LIQUIDATION_MODULE_KEY = bytes32("liquidationModule");
    bytes32 internal constant _KEEPER_FEE_MODULE_KEY = bytes32("keeperFee");
    bytes32 internal constant _CONTROLLER_MODULE_KEY = bytes32("controllerModule");
    bytes32 internal constant _POSITION_SPLITTER_MODULE_KEY = bytes32("positionSplitterModule");
}

// src/interfaces/structs/FlatcoinVaultStructs.sol

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

struct VaultSummary {
    int256 marketSkew;
    int256 cumulativeFundingRate;
    int256 lastRecomputedFundingRate;
    uint64 lastRecomputedFundingTimestamp;
    uint256 stableCollateralTotal;
    GlobalPositions globalPositions;
}

struct AuthorizedModule {
    bytes32 moduleKey;
    address moduleAddress;
}

// src/interfaces/IChainlinkAggregatorV3.sol

interface IChainlinkAggregatorV3 {
    function decimals() external view returns (uint8 decimals);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// src/interfaces/IEIP712.sol
/* solhint-disable */

interface IEIP712 {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
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

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// src/interfaces/IWETH.sol

/* solhint-disable gas-named-return-values */
interface IWETH {
    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function allowance(address, address) external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function decimals() external view returns (uint8);

    function deposit() external payable;

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(address src, address dst, uint256 wad) external returns (bool);

    function withdraw(uint256 wad) external;
}

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

// src/interfaces/structs/LeverageModuleStructs.sol

struct Position {
    uint256 averagePrice;
    uint256 marginDeposited;
    uint256 additionalSize;
    int256 entryCumulativeFunding;
}

struct PositionSummary {
    int256 profitLoss;
    int256 accruedFunding;
    int256 marginAfterSettlement;
}

struct MarketSummary {
    int256 profitLossTotalByLongs;
    int256 accruedFundingTotalByLongs;
    int256 currentFundingRate;
    int256 nextFundingEntry;
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

// src/interfaces/IOrderAnnouncementModule.sol

interface IOrderAnnouncementModule {
    // solhint-disable-next-line func-name-mixedcase
    function minDepositAmountUSD() external view returns (uint256 minStableDeposit);

    function minExecutabilityAge() external view returns (uint64 minExecutabilityAge);

    function authorizedCallers(address caller) external view returns (bool isAuthorized);

    function announceStableDeposit(uint256 depositAmount, uint256 minAmountOut, uint256 keeperFee) external;

    function announceLeverageOpen(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 keeperFee
    ) external;

    function announceLeverageOpenWithLimits(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFee
    ) external;

    function announceStableDepositFor(
        uint256 depositAmount,
        uint256 minAmountOut,
        uint256 keeperFee,
        address receiver
    ) external;

    function announceStableWithdraw(uint256 withdrawAmount, uint256 minAmountOut, uint256 keeperFee) external;

    function announceLeverageOpenFor(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFee,
        address receiver
    ) external;

    function announceLeverageAdjust(
        uint256 tokenId,
        int256 marginAdjustment,
        int256 additionalSizeAdjustment,
        uint256 fillPrice,
        uint256 keeperFee
    ) external;

    function announceLeverageClose(uint256 tokenId, uint256 minFillPrice, uint256 keeperFee) external;

    function announceLimitOrder(uint256 tokenId, uint256 stopLossPrice, uint256 profitTakePrice) external;

    function cancelLimitOrder(uint256 tokenId) external;

    function createLimitOrder(
        uint256 tokenId,
        address positionOwner,
        uint256 stopLossPrice,
        uint256 profitTakePrice
    ) external;

    function resetExecutionTime(uint256 tokenId) external;

    function deleteOrder(address account) external;

    function deleteLimitOrder(uint256 tokenId) external;

    function getAnnouncedOrder(address account) external view returns (Order memory order);

    function getLimitOrder(uint256 tokenId) external view returns (Order memory order);
}

// src/interfaces/ISignatureTransfer.sol
/* solhint-disable */

/// @title SignatureTransfer
/// @notice Handles ERC20 token transfers through signature based actions
/// @dev Requires user's token approval on the Permit2 contract

interface ISignatureTransfer is IEIP712 {
    /// @notice Thrown when the requested amount for a transfer is larger than the permissioned amount
    /// @param maxAmount The maximum amount a spender can request to transfer
    error InvalidAmount(uint256 maxAmount);

    /// @notice Thrown when the number of tokens permissioned to a spender does not match the number of tokens being transferred
    /// @dev If the spender does not need to transfer the number of tokens permitted, the spender can request amount 0 to be transferred
    error LengthMismatch();

    /// @notice Emits an event when the owner successfully invalidates an unordered nonce.
    event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);

    /// @notice The token and amount details for a transfer signed in the permit transfer signature
    struct TokenPermissions {
        // ERC20 token address
        address token;
        // the maximum amount that can be spent
        uint256 amount;
    }

    /// @notice The signed permit message for a single token transfer
    struct PermitTransferFrom {
        TokenPermissions permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice Specifies the recipient address and amount for batched transfers.
    /// @dev Recipients and amounts correspond to the index of the signed token permissions array.
    /// @dev Reverts if the requested amount is greater than the permitted signed amount.
    struct SignatureTransferDetails {
        // recipient address
        address to;
        // spender requested amount
        uint256 requestedAmount;
    }

    /// @notice Used to reconstruct the signed permit message for multiple token transfers
    /// @dev Do not need to pass in spender address as it is required that it is msg.sender
    /// @dev Note that a user still signs over a spender address
    struct PermitBatchTransferFrom {
        // the tokens and corresponding amounts permitted for a transfer
        TokenPermissions[] permitted;
        // a unique value for every token owner's signature to prevent signature replays
        uint256 nonce;
        // deadline on the permit signature
        uint256 deadline;
    }

    /// @notice A map from token owner address and a caller specified word index to a bitmap. Used to set bits in the bitmap to prevent against signature replay protection
    /// @dev Uses unordered nonces so that permit messages do not need to be spent in a certain order
    /// @dev The mapping is indexed first by the token owner, then by an index specified in the nonce
    /// @dev It returns a uint256 bitmap
    /// @dev The index, or wordPosition is capped at type(uint248).max
    function nonceBitmap(address, uint256) external view returns (uint256);

    /// @notice Transfers a token using a signed permit message
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Transfers a token using a signed permit message
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include the TokenPermissions type definition
    /// @dev Reverts if the requested amount is greater than the permitted signed amount
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the typehash
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param signature The signature to verify
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice Transfers multiple tokens using a signed permit message
    /// @dev The witness type string must follow EIP712 ordering of nested structs and must include the TokenPermissions type definition
    /// @notice Includes extra data provided by the caller to verify signature over
    /// @param permit The permit data signed over by the owner
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails Specifies the recipient and requested amount for the token transfer
    /// @param witness Extra data to include when checking the user signature
    /// @param witnessTypeString The EIP-712 type definition for remaining string stub of the typehash
    /// @param signature The signature to verify
    function permitWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;

    /// @notice Invalidates the bits specified in mask for the bitmap at the word position
    /// @dev The wordPos is maxed at type(uint248).max
    /// @param wordPos A number to index the nonceBitmap at
    /// @param mask A bitmap masked against msg.sender's current bitmap at the word position
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external;
}

// src/interfaces/structs/OracleModuleStructs.sol

enum PriceSource {
    OnChain,
    OffChain
}

struct OnchainOracle {
    IChainlinkAggregatorV3 oracleContract; // Chainlink oracle contract
    uint32 maxAge; // Oldest price that is acceptable to use
}

struct OffchainOracle {
    bytes32 priceId; // Pyth network price Id
    uint32 maxAge; // Oldest price that is acceptable to use
    uint32 minConfidenceRatio; // the minimum Pyth oracle price / expo ratio. The higher, the more confident the accuracy of the price.
}

struct OracleData {
    OnchainOracle onchainOracle;
    OffchainOracle offchainOracle;
    uint64 maxDiffPercent; // Max difference between onchain and offchain oracle. 1e18 = 100%
}

// src/misc/Swapper/TokenTransferMethodsStorage.sol

abstract contract TokenTransferMethodsStorage {
    // @custom:storage-location erc7201:Swapper.TokenTransferMethods
    struct TokenTransferMethodsStorageData {
        address permit2;
        IWETH wrappedNativeToken;
    }

    // keccak256(abi.encode(uint256(keccak256("Swapper.TokenTransferMethods")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _TOKEN_TRANSFER_METHODS_STORAGE_LOCATION =
        0xf443e521187c51ec1e29e6d8262f76dbe7d41015741854199897c2f773019d00;

    function getPermit2Address() public view returns (address permit2Address_) {
        return _getTokenTransferMethodsStorage().permit2;
    }

    function getWrappedNativeToken() public view returns (IWETH wrappedNativeToken_) {
        return _getTokenTransferMethodsStorage().wrappedNativeToken;
    }

    function _setPermit2Address(address permit2_) internal {
        _getTokenTransferMethodsStorage().permit2 = permit2_;
    }

    function _setWrappedNativeTokenAddress(IWETH wrappedNativeToken_) internal {
        _getTokenTransferMethodsStorage().wrappedNativeToken = wrappedNativeToken_;
    }

    function _getTokenTransferMethodsStorage() private pure returns (TokenTransferMethodsStorageData storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _TOKEN_TRANSFER_METHODS_STORAGE_LOCATION
        }
    }
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20Metadata.sol)

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

// src/interfaces/ICommonErrors.sol

interface ICommonErrors {
    ////////////////////////////////////////
    //               Errors               //
    ////////////////////////////////////////

    error MaxPositionsReached();

    error InvalidFee(uint256 fee);

    error PositionCreatesBadDebt();

    error ZeroValue(string variableName);

    error ZeroAddress(string variableName);

    error MaxSkewReached(uint256 skewFraction);

    error ValueNotPositive(string variableName);

    error OnlyAuthorizedModule(address msgSender);

    error InvalidPercentageValue(uint64 percentage);

    error HighSlippage(uint256 supplied, uint256 accepted);

    error ExecutableTimeNotReached(uint256 executableTime);

    error AmountTooSmall(uint256 amount, uint256 minAmount);

    error NotTokenOwner(uint256 tokenId, address msgSender);

    error OrderExists(OrderType orderType);

    error PriceStale(PriceSource priceSource);

    error PriceInvalid(PriceSource priceSource);

    error NotEnoughMarginForFees(int256 marginAmount, uint256 feeAmount);
}

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// src/libraries/SwapperStructs.sol

//////////////////////////
//    Structs & Enums   //
//////////////////////////

enum TransferMethod {
    ALLOWANCE,
    PERMIT2,
    NATIVE
}

enum Permit2TransferType {
    SINGLE_TRANSFER,
    BATCH_TRANSFER
}

struct Permit2EncodedData {
    Permit2TransferType transferType;
    bytes encodedData;
}

struct Permit2SingleTransfer {
    ISignatureTransfer.PermitTransferFrom permit;
    ISignatureTransfer.SignatureTransferDetails transferDetails;
    bytes signature;
}

struct Permit2BatchTransfer {
    ISignatureTransfer.PermitBatchTransferFrom permit;
    ISignatureTransfer.SignatureTransferDetails[] transferDetails;
    bytes signature;
}

/// @dev `methodData` here contains additional data for using the transfer method.
///       For `ALLOWANCE`, it's empty and for `PERMIT2`, it's encoded `Permit2EncodedData`.
struct TransferMethodData {
    TransferMethod method;
    bytes methodData;
}

struct SrcTokenSwapDetails {
    IERC20 token;
    uint256 amount;
    AggregatorData aggregatorData;
}

struct SrcData {
    SrcTokenSwapDetails[] srcTokenSwapDetails;
    TransferMethodData transferMethodData;
}

struct DestData {
    IERC20 destToken;
    uint256 minDestAmount;
}

struct AggregatorData {
    bytes32 routerKey;
    bytes swapData;
}

struct InOutData {
    SrcData[] srcData;
    DestData destData;
}

// src/interfaces/ISwapper.sol

interface ISwapper {
    function swap(InOutData calldata swapStruct_) external payable;
}

// src/interfaces/IFlatcoinVault.sol

interface IFlatcoinVault {
    function collateral() external view returns (IERC20Metadata collateral);

    function stableCollateralTotal() external view returns (uint256 totalAmount);

    function stableCollateralCap() external view returns (uint256 collateralCap);

    function skewFractionMax() external view returns (uint256 skewFractionMax);

    function maxDeltaError() external view returns (uint256 maxDeltaError);

    function maxPositions() external view returns (uint256 maxPositions);

    function moduleAddress(bytes32 moduleKey) external view returns (address moduleAddress);

    function isAuthorizedModule(address module) external view returns (bool status);

    function isModulePaused(bytes32 moduleKey) external view returns (bool paused);

    function sendCollateral(address to, uint256 amount) external;

    function setPosition(Position memory position, uint256 tokenId) external;

    function deletePosition(uint256 tokenId) external;

    function updateStableCollateralTotal(int256 stableCollateralAdjustment) external;

    function updateGlobalMargin(int256 marginDelta) external;

    function updateGlobalPositionData(uint256 price, int256 marginDelta, int256 additionalSizeDelta) external;

    function isPositionOpenWhitelisted(address account) external view returns (bool whitelisted);

    function isMaxPositionsReached() external view returns (bool maxPositionsReached);

    function getMaxPositionIds() external view returns (uint256[] memory openPositionIds);

    function getPosition(uint256 tokenId) external view returns (Position memory position);

    function getGlobalPositions() external view returns (GlobalPositions memory globalPositions);

    function checkSkewMax(uint256 sizeChange, int256 stableCollateralChange) external view;

    function checkCollateralCap(uint256 depositAmount) external view;

    function checkGlobalMarginPositive() external view;
}

// src/abstracts/FeeManager.sol

/// @title FeeManager
/// @author dHEDGE
/// @notice Fees management contract for the protocol.
abstract contract FeeManager is OwnableUpgradeable {
    ///////////////////////////////
    //           State           //
    ///////////////////////////////

    /// @notice Protocol fee collection address.
    address public protocolFeeRecipient;

    /// @notice The protocol fee percentage.
    /// @dev 1e18 = 100%
    uint64 public protocolFeePercentage;

    /// @notice Fee for stable LP redemptions.
    /// @dev 1e18 = 100%
    uint64 public stableWithdrawFee;

    /// @notice Charged for opening, adjusting or closing a position.
    /// @dev 1e18 = 100%
    uint64 public leverageTradingFee;

    ///////////////////////////////
    //    Initializer Function   //
    ///////////////////////////////

    // solhint-disable-next-line func-name-mixedcase
    function __FeeManager_init(
        address protocolFeeRecipient_,
        uint64 protocolFeePercentage_,
        uint64 stableWithdrawFee_,
        uint64 leverageTradingFee_
    ) internal {
        protocolFeeRecipient = protocolFeeRecipient_;
        protocolFeePercentage = protocolFeePercentage_;
        stableWithdrawFee = stableWithdrawFee_;
        leverageTradingFee = leverageTradingFee_;
    }

    ///////////////////////////////
    //      View Functions       //
    ///////////////////////////////

    /// @notice Returns the trade fee for a given size.
    /// @param size_ The size of the trade.
    /// @return tradeFee_ The trade fee.
    function getTradeFee(uint256 size_) external view returns (uint256 tradeFee_) {
        return (leverageTradingFee * size_) / 1e18;
    }

    function getWithdrawalFee(uint256 amount_) external view returns (uint256 withdrawalFee_) {
        return (stableWithdrawFee * amount_) / 1e18;
    }

    /// @notice Returns the protocol fee portion for a given trade fee amount.
    /// @param feeAmount_ The trade fee amount.
    /// @return protocolFeePortion_ The protocol fee portion.
    function getProtocolFee(uint256 feeAmount_) external view returns (uint256 protocolFeePortion_) {
        return (feeAmount_ * protocolFeePercentage) / 1e18;
    }

    ///////////////////////////////
    //     Private Functions     //
    ///////////////////////////////

    function _setProtocolFeeRecipient(address protocolFeeRecipient_) private {
        if (protocolFeeRecipient_ == address(0)) revert ICommonErrors.ZeroAddress("protocolFeeRecipient");

        protocolFeeRecipient = protocolFeeRecipient_;
    }

    function _setProtocolFeePercentage(uint64 protocolFeePercentage_) private {
        if (protocolFeePercentage_ > 1e18) revert ICommonErrors.InvalidPercentageValue(protocolFeePercentage_);

        protocolFeePercentage = protocolFeePercentage_;
    }

    function _setStableWithdrawFee(uint64 stableWithdrawFee_) private {
        if (stableWithdrawFee_ > 1e18) revert ICommonErrors.InvalidPercentageValue(stableWithdrawFee_);

        stableWithdrawFee = stableWithdrawFee_;
    }

    function _setLeverageTradingFee(uint64 leverageTradingFee_) private {
        if (leverageTradingFee_ > 1e18) revert ICommonErrors.InvalidPercentageValue(leverageTradingFee_);

        leverageTradingFee = leverageTradingFee_;
    }

    ///////////////////////////////
    //      Owner Functions      //
    ///////////////////////////////

    /// @notice Setter for the protocol fee recipient address.
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient.
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external onlyOwner {
        _setProtocolFeeRecipient(protocolFeeRecipient_);
    }

    /// @notice Setter for the protocol fee percentage.
    /// @param protocolFeePercentage_ The new protocol fee percentage.
    function setProtocolFeePercentage(uint64 protocolFeePercentage_) external onlyOwner {
        _setProtocolFeePercentage(protocolFeePercentage_);
    }

    /// @notice Setter for the leverage open/close fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param leverageTradingFee_ The new leverage trading fee.
    function setLeverageTradingFee(uint64 leverageTradingFee_) external onlyOwner {
        _setLeverageTradingFee(leverageTradingFee_);
    }

    /// @notice Setter for the stable withdraw fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param stableWithdrawFee_ The new stable withdraw fee.
    function setStableWithdrawFee(uint64 stableWithdrawFee_) external onlyOwner {
        _setStableWithdrawFee(stableWithdrawFee_);
    }

    uint256[46] private __gap;
}

// src/misc/Swapper/TokenTransferMethods.sol

abstract contract TokenTransferMethods is TokenTransferMethodsStorage {
    using SafeERC20 for IERC20;

    error UnsupportedTokenTransferMethod();
    error NativeTokenSentWithoutNativeSwap();
    error InvalidNativeTokenTransferEncoding();
    error NotEnoughNativeTokenSent(uint256 expectedAmount, uint256 sentAmount);
    error UnsupportedPermit2Method(Permit2TransferType transferType);
    error AmountsAfterPermit2TransferMismatch(address token, uint256 expectedAmount, uint256 actualAmount);

    // solhint-disable-next-line func-name-mixedcase
    function __TokenTransferMethods_init(address permit2_, IWETH wrappedNativeToken_) internal {
        // Note that we aren't checking for the zero address here.
        // This is to avoid having the inheriting contract pass a valid address on chains where the permit2 contract is not deployed
        // and there is no wrappen native contract.
        _setPermit2Address(permit2_);
        _setWrappedNativeTokenAddress(wrappedNativeToken_);
    }

    /// @dev Transfer tokens from sender to the inheriting contract.
    function _transferFromCaller(address from_, SrcData[] memory srcData) internal virtual {
        bool nativeSwapIncluded;

        // Iterate over all the `TokenTransferMethods` used in the swap.
        for (uint8 i; i < srcData.length; ++i) {
            TransferMethod transferMethod = srcData[i].transferMethodData.method;

            if (transferMethod == TransferMethod.ALLOWANCE) {
                _transferUsingSimpleAllowance(from_, srcData[i]);
            } else if (transferMethod == TransferMethod.PERMIT2) {
                _transferUsingPermit2(from_, srcData[i]);
            } else if (transferMethod == TransferMethod.NATIVE) {
                nativeSwapIncluded = true;

                // Use native token wrapper to wrap to wrapped equivalent.
                _wrapNativeToken(srcData[i]);
            } else {
                revert UnsupportedTokenTransferMethod();
            }
        }

        // We revert if native token is sent without a native asset swapdata included in the `srcData`.
        if (!nativeSwapIncluded && msg.value > 0) revert NativeTokenSentWithoutNativeSwap();
    }

    function _transferUsingSimpleAllowance(address from_, SrcData memory srcData_) internal virtual {
        for (uint256 i; i < srcData_.srcTokenSwapDetails.length; ++i) {
            srcData_.srcTokenSwapDetails[i].token.safeTransferFrom(
                from_,
                address(this),
                srcData_.srcTokenSwapDetails[i].amount
            );
        }
    }

    /// @dev Note that the inheriting contract should be the receiver of the tokens.
    /// @dev Note that if any other token signature is provided, that token will be transferred
    ///      but the transaction won't revert. It will be stuck in the contract.
    function _transferUsingPermit2(address from_, SrcData memory srcData_) internal virtual {
        Permit2EncodedData memory permit2Data = abi.decode(
            srcData_.transferMethodData.methodData,
            (Permit2EncodedData)
        );

        uint256[] memory previousBalances = new uint256[](srcData_.srcTokenSwapDetails.length);
        for (uint256 i; i < srcData_.srcTokenSwapDetails.length; ++i) {
            previousBalances[i] = srcData_.srcTokenSwapDetails[i].token.balanceOf(address(this));
        }

        if (permit2Data.transferType == Permit2TransferType.SINGLE_TRANSFER) {
            Permit2SingleTransfer memory singleTransferData = abi.decode(
                permit2Data.encodedData,
                (Permit2SingleTransfer)
            );

            ISignatureTransfer(getPermit2Address()).permitTransferFrom(
                singleTransferData.permit,
                singleTransferData.transferDetails,
                from_,
                singleTransferData.signature
            );
        } else if (permit2Data.transferType == Permit2TransferType.BATCH_TRANSFER) {
            Permit2BatchTransfer memory batchTransferData = abi.decode(permit2Data.encodedData, (Permit2BatchTransfer));

            ISignatureTransfer(getPermit2Address()).permitTransferFrom(
                batchTransferData.permit,
                batchTransferData.transferDetails,
                from_,
                batchTransferData.signature
            );
        } else {
            revert UnsupportedPermit2Method(permit2Data.transferType);
        }

        // Check that the received amounts are as expected.
        for (uint256 i; i < srcData_.srcTokenSwapDetails.length; ++i) {
            uint256 newBalance = srcData_.srcTokenSwapDetails[i].token.balanceOf(address(this));
            uint256 delta = newBalance - previousBalances[i];

            if (delta != srcData_.srcTokenSwapDetails[i].amount)
                revert AmountsAfterPermit2TransferMismatch(
                    address(srcData_.srcTokenSwapDetails[i].token),
                    srcData_.srcTokenSwapDetails[i].amount,
                    delta
                );
        }
    }

    function _wrapNativeToken(SrcData memory srcData) internal virtual {
        IWETH wrappedNativeToken = getWrappedNativeToken();

        if (
            srcData.srcTokenSwapDetails.length != 1 ||
            srcData.srcTokenSwapDetails[0].token != IERC20(address(wrappedNativeToken))
        ) revert InvalidNativeTokenTransferEncoding();
        if (msg.value != srcData.srcTokenSwapDetails[0].amount)
            revert NotEnoughNativeTokenSent(srcData.srcTokenSwapDetails[0].amount, msg.value);

        wrappedNativeToken.deposit{value: msg.value}();
    }
}

// src/misc/FlatZapper/FlatZapperStorage.sol

abstract contract FlatZapperStorage {
    // @custom:storage-location erc7201:FlatZapper
    struct FlatZapperStorageData {
        IERC20 collateral;
        IFlatcoinVault vault;
        ISwapper swapper;
    }

    // keccak256(abi.encode(uint256(keccak256("FlatZapper")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _FLATZAPPER_STORAGE_LOCATION =
        0xd864549198ec95d704c0a8cce160d13cbd5509cdd8c7e567bb2b8fe66fc5ce00;

    // solhint-disable-next-line func-name-mixedcase
    function __FlatZapperStorage_init(IERC20 collateral_, IFlatcoinVault vault_, ISwapper swapper_) internal {
        FlatZapperStorageData storage zapperStorage = _getFlatZapperStorage();

        zapperStorage.collateral = collateral_;
        zapperStorage.vault = vault_;
        zapperStorage.swapper = swapper_;
    }

    function getCollateral() public view returns (IERC20 collateral_) {
        return _getFlatZapperStorage().collateral;
    }

    function getVault() public view returns (IFlatcoinVault vault_) {
        return _getFlatZapperStorage().vault;
    }

    function getSwapper() public view returns (ISwapper swapper_) {
        return _getFlatZapperStorage().swapper;
    }

    function _setVault(IFlatcoinVault vault_) internal {
        _getFlatZapperStorage().vault = vault_;
    }

    function _setCollateral(IERC20 collateral_) internal {
        _getFlatZapperStorage().collateral = collateral_;
    }

    function _setSwapper(ISwapper swapper_) internal {
        _getFlatZapperStorage().swapper = swapper_;
    }

    function _getFlatZapperStorage() private pure returns (FlatZapperStorageData storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _FLATZAPPER_STORAGE_LOCATION
        }
    }
}

// src/misc/FlatZapper/FlatZapper.sol

/// @title FlatZapper
/// @author dHEDGE
/// @notice Contract to swap tokens to the collateral token and announce an order to the Flat Money Protocol.
/// @dev Follows the new ERC7201 storage pattern.
contract FlatZapper is FlatZapperStorage, OwnableUpgradeable, TokenTransferMethods {
    using SafeERC20 for IERC20;

    //////////////////////////
    //        Events        //
    //////////////////////////

    event ZapCompleted(address indexed sender, OrderType indexed orderType);

    //////////////////////////
    //        Errors        //
    //////////////////////////

    error InvalidOrderType();
    error ZeroAddress(string variableName);
    error AmountReceivedForMarginTooSmall(uint256 receivedAmount, uint256 minMargin);
    error NotEnoughCollateralAfterFees(uint256 collateralReceived, uint256 fees);

    /////////////////////////
    //       Structs       //
    /////////////////////////

    struct DepositData {
        uint256 minAmountOut;
        uint256 keeperFee;
    }

    /// @dev Note that if a user doesn't want a limit order to be placed, they can set the `stopLossPrice` and `profitTakePrice`
    ///      as `0` and `type(uint256).max` respectively.
    struct LeverageOpenData {
        uint256 minMargin;
        uint256 additionalSize;
        uint256 maxFillPrice;
        uint256 stopLossPrice;
        uint256 profitTakePrice;
        uint256 keeperFee;
    }

    struct AnnouncementData {
        OrderType orderType;
        bytes data;
    }

    //////////////////////////
    //       Functions      //
    //////////////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        IFlatcoinVault vault_,
        IERC20 collateral_,
        ISwapper swapper_,
        address orderAnnouncementModule_,
        address permit2_,
        IWETH wrappedNativeToken_
    ) external initializer {
        __Ownable_init(owner_);

        if (address(vault_) == address(0) || address(collateral_) == address(0) || address(swapper_) == address(0))
            revert ZeroAddress("vault|collateral|swapper");

        __FlatZapperStorage_init({vault_: vault_, collateral_: collateral_, swapper_: swapper_});

        __TokenTransferMethods_init(permit2_, wrappedNativeToken_);

        // Approve the order announcement module to spend `collateral_`.
        // As this contract won't hold any `collateral_` for a significant time, we can approve it to spend an unlimited amount.
        _unlimitedApprove(collateral_, orderAnnouncementModule_);
    }

    /// @notice Zaps into the Flat Money Protocol.
    /// @dev This function is used to swap the source token to the collateral token and announce an order to the Flat Money Protocol.
    /// @dev The `srcData` in the `swapStruct_` should contain the data required to transfer the source token(s) to this contract.
    ///      and not to the Swapper contract.
    /// @param swapStruct_ The data required to swap the source token(s) to the collateral token(s).
    /// @param announcementData_ The data required to announce the order to the Flat Money Protocol.
    function zap(InOutData calldata swapStruct_, AnnouncementData calldata announcementData_) external payable {
        IERC20 collateral = getCollateral();

        uint256 collateralBalanceBefore = collateral.balanceOf(address(this));

        _transferFromCaller(msg.sender, swapStruct_.srcData);
        _swap(swapStruct_);

        uint256 collateralReceived = collateral.balanceOf(address(this)) - collateralBalanceBefore;

        _createOrder(announcementData_, collateralReceived);

        emit ZapCompleted({sender: msg.sender, orderType: announcementData_.orderType});
    }

    function _swap(InOutData memory swapStruct_) internal {
        ISwapper swapper = getSwapper();

        uint256 numSrcTokens;
        for (uint256 i; i < swapStruct_.srcData.length; ++i) {
            numSrcTokens += swapStruct_.srcData[i].srcTokenSwapDetails.length;
        }

        // We only require a single element in the array as we are only going to use the
        // simple allowance transfer method to transfer `srcTokens` from this contract to
        // the swapper.
        SrcData[] memory newSrcData = new SrcData[](1);
        newSrcData[0].srcTokenSwapDetails = new SrcTokenSwapDetails[](numSrcTokens);

        // Although not required to be set explicitly, we are setting the transfer method to `ALLOWANCE`.
        newSrcData[0].transferMethodData.method = TransferMethod.ALLOWANCE;

        uint256 srcTokenIndex;
        for (uint256 i; i < swapStruct_.srcData.length; ++i) {
            for (uint256 j; j < swapStruct_.srcData[i].srcTokenSwapDetails.length; ++j) {
                newSrcData[0].srcTokenSwapDetails[srcTokenIndex++] = SrcTokenSwapDetails({
                    token: swapStruct_.srcData[i].srcTokenSwapDetails[j].token,
                    amount: swapStruct_.srcData[i].srcTokenSwapDetails[j].amount,
                    aggregatorData: swapStruct_.srcData[i].srcTokenSwapDetails[j].aggregatorData
                });

                // Max approve the Swapper to spend the source token.
                _unlimitedApprove(swapStruct_.srcData[i].srcTokenSwapDetails[j].token, address(swapper));
            }
        }

        swapStruct_.srcData = newSrcData;

        swapper.swap(swapStruct_);
    }

    function _createOrder(AnnouncementData calldata announcementData_, uint256 collateralAmount_) internal {
        IFlatcoinVault vault = getVault();

        if (announcementData_.orderType == OrderType.StableDeposit) {
            DepositData memory depositAnnouncementData = abi.decode(announcementData_.data, (DepositData));

            // Ensure that the collateral received is greater than the keeper fee.
            if (collateralAmount_ <= depositAnnouncementData.keeperFee)
                revert NotEnoughCollateralAfterFees(collateralAmount_, depositAnnouncementData.keeperFee);

            // Note that as the keeper fee is deducted from the collateral, it becomes crucial to calculate the minAmountOut correctly
            // by accounting for the slippage incurred during the swap.
            // We are subtracting the keeper fee from the collateral received as the amount of collateral transferred to the
            // OrderExecution module is equivalent to the `depositAmount + keeperFee`.
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .announceStableDepositFor({
                    depositAmount: collateralAmount_ - depositAnnouncementData.keeperFee,
                    minAmountOut: depositAnnouncementData.minAmountOut,
                    keeperFee: depositAnnouncementData.keeperFee,
                    receiver: msg.sender
                });
        } else if (announcementData_.orderType == OrderType.LeverageOpen) {
            LeverageOpenData memory leverageOpenData = abi.decode(announcementData_.data, (LeverageOpenData));

            uint256 fees = leverageOpenData.keeperFee +
                FeeManager(address(vault)).getTradeFee(leverageOpenData.additionalSize);

            // Ensure that the collateral received is greater than the fees to be paid.
            if (collateralAmount_ <= fees) revert NotEnoughCollateralAfterFees(collateralAmount_, fees);

            uint256 margin = collateralAmount_ - fees;

            // As the keeper fee and trade fee is deducted from the collateral, we need to ensure that the margin is sufficient.
            if (margin < leverageOpenData.minMargin)
                revert AmountReceivedForMarginTooSmall(collateralAmount_, leverageOpenData.minMargin);

            // We are subtracting the keeper fee from the collateral received as the amount of collateral transferred to the
            // OrderExecution module is equivalent to the `margin + keeperFee + tradeFee`.
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .announceLeverageOpenFor({
                    margin: margin,
                    additionalSize: leverageOpenData.additionalSize,
                    maxFillPrice: leverageOpenData.maxFillPrice,
                    stopLossPrice: leverageOpenData.stopLossPrice,
                    profitTakePrice: leverageOpenData.profitTakePrice,
                    keeperFee: leverageOpenData.keeperFee,
                    receiver: msg.sender
                });
        } else {
            revert InvalidOrderType();
        }
    }

    /// @dev Function to approve the spender to spend an unlimited amount of the token.
    /// @dev The function checks if the allowance is less than half of the `uint256` max value before max approving.
    ///      Because if it compared with uint256 max value, it will always be less than that.
    /// @param token_ The token to approve.
    /// @param spender_ The address to approve.
    function _unlimitedApprove(IERC20 token_, address spender_) private {
        uint256 currentAllowance = token_.allowance(address(this), spender_);
        if (currentAllowance < type(uint256).max / 2)
            token_.safeIncreaseAllowance(spender_, type(uint256).max - currentAllowance);
    }

    //////////////////////////
    //    Admin functions   //
    //////////////////////////

    /// @notice Sets the address of the FlatcoinVault to zap into.
    /// @param vault_ The address of the collateral token.
    function setVault(IFlatcoinVault vault_) external onlyOwner {
        if (address(vault_) == address(0)) revert ZeroAddress("vault");

        _setVault(vault_);
    }

    /// @notice Sets the address of the collateral token.
    /// @dev Useful in case the collateral token is updated.
    /// @param newCollateral_ The address of the collateral token.
    function setCollateral(IERC20 newCollateral_) external onlyOwner {
        if (address(newCollateral_) == address(0)) revert ZeroAddress("newCollateral");

        _setCollateral(newCollateral_);
        _unlimitedApprove(newCollateral_, getVault().moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY));
    }

    /// @notice Sets the address of the Swapper contract.
    /// @param newSwapper_ The address of the Swapper contract.
    function setSwapper(ISwapper newSwapper_) external onlyOwner {
        if (address(newSwapper_) == address(0)) revert ZeroAddress("newSwapper");

        _setSwapper(newSwapper_);
    }

    /// @notice Approve the order announcement module to spend an unlimited amount of the collateral token.
    /// @dev In case the OrderAnnouncement module is updated, this function can be called to approve the new module address.
    function unlimitedApproveOrderAnnouncementModule() external onlyOwner {
        address orderAnnouncementModule = getVault().moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY);

        _unlimitedApprove(getCollateral(), orderAnnouncementModule);
    }

    /// @notice Rescue funds from the contract.
    /// @param token_ Address of the token to be rescued.
    /// @param to_ Address to which the funds will be transferred.
    /// @param amount_ Amount of tokens to be rescued.
    function rescueFunds(IERC20 token_, address to_, uint256 amount_) external onlyOwner {
        token_.safeTransfer(to_, amount_);
    }

    function setWrappedNativeToken(IWETH wrappedNativeToken_) external onlyOwner {
        _setWrappedNativeTokenAddress(wrappedNativeToken_);
    }
}
