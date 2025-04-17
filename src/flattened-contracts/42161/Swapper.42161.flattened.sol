// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity =0.8.28 ^0.8.20 ^0.8.28;

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

// src/interfaces/IEIP712.sol
/* solhint-disable */

interface IEIP712 {
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

// src/misc/Swapper/RouterProcessorStorage.sol

abstract contract RouterProcessorStorage {
    // @custom:storage-location erc7201:Swapper.RouterProcessor
    struct RouterProcessesorStorageData {
        mapping(bytes32 routerKey => address routerAddress) routers;
    }

    // keccak256(abi.encode(uint256(keccak256("Swapper.RouterProcessor")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _ROUTER_PROCESSOR_STORAGE_LOCATION =
        0x4cf853a34ccdbeaaf639a4ff5f4912cf72bb597aabb8eb66c2a38478d7f72300;

    function getRouter(bytes32 routerKey_) public view returns (address routerAddress_) {
        return _getRouterProcessorStorage().routers[routerKey_];
    }

    function _addRouter(bytes32 routerKey_, address router_) internal {
        _getRouterProcessorStorage().routers[routerKey_] = router_;
    }

    function _removeRouter(bytes32 routerKey_) internal {
        delete _getRouterProcessorStorage().routers[routerKey_];
    }

    function _getRouterProcessorStorage() private pure returns (RouterProcessesorStorageData storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _ROUTER_PROCESSOR_STORAGE_LOCATION
        }
    }
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

// src/misc/Swapper/RouterProcessor.sol

abstract contract RouterProcessor is RouterProcessorStorage {
    using SafeERC20 for IERC20;

    //////////////////////////
    //        Events        //
    //////////////////////////

    event SwapComplete(address indexed router, SrcTokenSwapDetails indexed srcTokenSwapDetails);

    //////////////////////////
    //        Errors        //
    //////////////////////////

    error InvalidAggregator(bytes32 routerKey);
    error FailedToApproveParaswap(bytes returnData);
    error SwapFailed(address router, SrcTokenSwapDetails srcTokenSwapDetails, bytes returnData);
    error EmptyPayload();

    //////////////////////////
    //       Functions      //
    //////////////////////////

    function _processSwap(SrcTokenSwapDetails memory srcTokenSwapDetails_) internal {
        bytes32 routerKey = srcTokenSwapDetails_.aggregatorData.routerKey;
        address router = getRouter(routerKey);

        if (router == address(0)) revert InvalidAggregator(routerKey);

        if (srcTokenSwapDetails_.aggregatorData.swapData.length == 0) revert EmptyPayload();

        address contractToApprove;
        bool success;
        bytes memory returnData;

        // In case the aggregator to be used is Paraswap then we need to approve the TokenTransferProxy contract.
        contractToApprove = (routerKey == bytes32("PARASWAP")) ? _preParaswap(router) : router;

        (success, returnData) = _approveAndCallRouter({
            srcTokenSwapDetails_: srcTokenSwapDetails_,
            contractToApprove_: contractToApprove,
            router_: router
        });

        if (!success) revert SwapFailed(router, srcTokenSwapDetails_, returnData);

        emit SwapComplete(router, srcTokenSwapDetails_);
    }

    /// @dev Returns the remaining source token amount to the caller.
    function _approveAndCallRouter(
        SrcTokenSwapDetails memory srcTokenSwapDetails_,
        address contractToApprove_,
        address router_
    ) private returns (bool success_, bytes memory returnData_) {
        uint256 currentAllowance = srcTokenSwapDetails_.token.allowance(address(this), contractToApprove_);

        // Contract balance of source token before caller initiated the transaction.
        uint256 balanceBeforeSwap = srcTokenSwapDetails_.token.balanceOf(address(this)) - srcTokenSwapDetails_.amount;

        // We max approve the contract which will take the `srcToken_` as it reduces the number of approval calls in the future.
        // This should be safe as long as this contract doesn't hold tokens after a swap.
        if (currentAllowance < srcTokenSwapDetails_.amount)
            srcTokenSwapDetails_.token.safeIncreaseAllowance(contractToApprove_, type(uint256).max - currentAllowance);

        // solhint-disable-next-line avoid-low-level-calls
        (success_, returnData_) = router_.call(srcTokenSwapDetails_.aggregatorData.swapData);

        uint256 balanceAfterSwap = srcTokenSwapDetails_.token.balanceOf(address(this));

        // Return the remaining tokens to the caller.
        if (balanceAfterSwap > balanceBeforeSwap) {
            srcTokenSwapDetails_.token.safeTransfer(msg.sender, balanceAfterSwap - balanceBeforeSwap);
        }
    }

    function _preParaswap(address router_) private view returns (address contractToApprove_) {
        // In certain cases, the `srcToken` required for swapping is taken by a different contract than the router.
        // This is the case for Paraswap, where the TokenTransferProxy contract is used to transfer the token.

        // solhint-disable-next-line avoid-low-level-calls
        (bool fetchSuccess, bytes memory fetchedData) = router_.staticcall(
            abi.encodeWithSignature("getTokenTransferProxy()")
        );
        if (!fetchSuccess) revert FailedToApproveParaswap(fetchedData);

        contractToApprove_ = abi.decode(fetchedData, (address));
    }
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

// src/misc/Swapper/Swapper.sol

contract Swapper is ISwapper, RouterProcessor, TokenTransferMethods, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    //////////////////////////
    //        Events        //
    //////////////////////////

    event RouterAdded(bytes32 indexed routerKey, address router);
    event RouterRemoved(bytes32 indexed routerKey);

    //////////////////////////
    //        Errors        //
    //////////////////////////

    error ZeroAddress(string field);
    error InsufficientAmountReceived(IERC20 destToken, uint256 receivedAmount, uint256 minAmount);

    //////////////////////////
    //       Functions      //
    //////////////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address permit2_, IWETH wrappedNativeToken_) external initializer {
        __Ownable_init(owner_);
        __TokenTransferMethods_init(permit2_, wrappedNativeToken_);
    }

    /// @notice Swap tokens using the given `swapStruct_`.
    /// @dev Only supports SINGLE_IN_SINGLE_OUT and MULTI_IN_SINGLE_OUT swap types.
    /// @param swapStruct_ The struct containing all the data required to process the swap(s).
    function swap(InOutData calldata swapStruct_) external payable {
        uint256 destAmountBefore = swapStruct_.destData.destToken.balanceOf(address(this));

        // Transfer all the `srcTokens` to this contract.
        _transferFromCaller(msg.sender, swapStruct_.srcData);

        // Process swaps based on `srcData` array.
        // The first loop iterates over the `srcData` array. The number of iterations is equal to the number of transfer methods used in the swap.
        // For example if the swap uses `TokenTransferMethod.ALLOWANCE` for all `srcTokens`, then the outer loop will iterate only once.
        // If the swap uses `TransferMethod.ALLOWANCE` for the first x `srcTokens` and `TransferMethod.PERMIT` for the next y `srcTokens`,
        // then the outer loop will iterate twice.
        for (uint256 i; i < swapStruct_.srcData.length; ++i) {
            // The second loop iterates over the `srcTokens` array in which the `srcTokens` are transferred and swapped using the same token transfer method.
            for (uint256 j; j < swapStruct_.srcData[i].srcTokenSwapDetails.length; ++j) {
                _processSwap({srcTokenSwapDetails_: swapStruct_.srcData[i].srcTokenSwapDetails[j]});
            }
        }

        // Check that we got enough of each `destToken` after processing and transfer them to the caller.
        // Note that we don't consider the current `destToken` balance of this contract as the received amount
        // as the amount can be more than the actual received amount due to someone else transferring tokens to this contract.
        // The following approach gives us the ability to rescue funds from this contract.
        uint256 destAmountReceived = swapStruct_.destData.destToken.balanceOf(address(this)) - destAmountBefore;

        if (destAmountReceived < swapStruct_.destData.minDestAmount)
            revert InsufficientAmountReceived(
                swapStruct_.destData.destToken,
                destAmountReceived,
                swapStruct_.destData.minDestAmount
            );

        swapStruct_.destData.destToken.safeTransfer(msg.sender, destAmountReceived);
    }

    //////////////////////////
    //    Admin functions   //
    //////////////////////////

    /// @notice Add a new router to the whitelist.
    /// @dev Note that this function will modify the router address if the given key already exists.
    /// @param routerKey_ A unique key to identify the router.
    /// @param router_ Address of the router.
    function addRouter(bytes32 routerKey_, address router_) external onlyOwner {
        if (router_ == address(0)) revert ZeroAddress("router");

        _addRouter(routerKey_, router_);

        emit RouterAdded(routerKey_, router_);
    }

    /// @notice Remove a router from the whitelist.
    /// @param routerKey_ The key of the router to be removed.
    function removeRouter(bytes32 routerKey_) external onlyOwner {
        if (getRouter(routerKey_) == address(0)) revert ZeroAddress("router");

        _removeRouter(routerKey_);

        emit RouterRemoved(routerKey_);
    }

    /// @notice Rescue funds from the contract.
    /// @param token_ Address of the token to be rescued.
    /// @param to_ Address to which the funds will be transferred.
    /// @param amount_ Amount of tokens to be rescued.
    function rescueFunds(IERC20 token_, address to_, uint256 amount_) external onlyOwner {
        token_.safeTransfer(to_, amount_);
    }

    /// @notice Sets the wrapped equivalent of native token's contract address.
    /// @dev This is intended to be used once as this is the new state variable introduced in the newer version
    ///      of the TokenTransferMethods contract.
    /// @param wrappedNativeToken_ Address of the wrapped native token contract.
    function setWrappedNativeToken(IWETH wrappedNativeToken_) external onlyOwner {
        _setWrappedNativeTokenAddress(wrappedNativeToken_);
    }
}
