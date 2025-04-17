// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity =0.8.28 ^0.8.0 ^0.8.20 ^0.8.28;

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

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }
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

// src/interfaces/IKeeperFee.sol

interface IKeeperFee {
    function getKeeperFee() external view returns (uint256 keeperFee);

    function getKeeperFee(uint256 baseFee) external view returns (uint256 keeperFee);

    function getConfig()
        external
        view
        returns (
            uint256 profitMarginPercent,
            uint256 minKeeperFeeUpperBound,
            uint256 minKeeperFeeLowerBound,
            uint256 gasUnitsL1,
            uint256 gasUnitsL2
        );

    function setParameters(uint256 keeperFeeUpperBound, uint256 keeperFeeLowerBound) external;

    function setKeeperFee(uint256 keeperFee) external;
}

// src/interfaces/ILiquidationModule.sol

interface ILiquidationModule {
    function liquidationFeeRatio() external view returns (uint128 liquidationFeeRatio);

    function liquidationBufferRatio() external view returns (uint128 liquidationBufferRatio);

    function liquidationFeeUpperBound() external view returns (uint256 feeUpperBound);

    function liquidationFeeLowerBound() external view returns (uint256 feeLowerBound);

    function liquidate(uint256 tokenID, bytes[] calldata priceUpdateData) external payable;

    function liquidate(uint256 tokenID) external;

    function liquidate(
        uint256[] calldata tokenID,
        bytes[] calldata priceUpdateData
    ) external payable returns (uint256[] memory liquidatedIDs);

    function liquidate(uint256[] calldata tokenID) external returns (uint256[] memory liquidatedIDs);

    function canLiquidate(uint256 tokenId) external view returns (bool liquidatable);

    function canLiquidate(uint256 tokenId, uint256 price) external view returns (bool liquidatable);

    function getLiquidationFee(uint256 tokenId) external view returns (uint256 liquidationFee);

    function getLiquidationMargin(uint256 additionalSize) external view returns (uint256 liquidationMargin);

    function getLiquidationMargin(
        uint256 additionalSize,
        uint256 price
    ) external view returns (uint256 liquidationMargin);

    function getLiquidationFee(uint256 positionSize, uint256 price) external view returns (uint256 liquidationFee);
}

// src/interfaces/IOrderExecutionModule.sol

interface IOrderExecutionModule {
    function maxExecutabilityAge() external view returns (uint64 maxExecutabilityAge);

    function executeOrder(address account, bytes[] memory priceUpdateData) external payable;

    function executeLimitOrder(uint256 tokenId, bytes[] calldata priceUpdateData) external payable;

    function cancelExistingOrder(address account) external;

    function cancelOrderByModule(address account) external;

    function hasOrderExpired(address account) external view returns (bool expired);
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

// src/interfaces/IControllerModule.sol

interface IControllerModule {
    // solhint-disable-next-line func-name-mixedcase
    function CONTROLLER_TYPE() external view returns (uint8 controllerType);

    function settleFundingFees() external;

    function cumulativeFundingRate() external view returns (int256 cumulativeFundingRate);

    function lastRecomputedFundingTimestamp() external view returns (uint64 lastRecomputedFundingTimestamp);

    function lastRecomputedFundingRate() external view returns (int256 lastRecomputedFundingRate);

    function maxFundingVelocity() external view returns (uint256 maxFundingVelocity);

    function maxVelocitySkew() external view returns (uint256 maxVelocitySkew);

    function targetSizeCollateralRatio() external view returns (uint256 targetSizeCollateralRatio);

    function currentFundingRate() external view returns (int256 currFundingRate);

    function nextFundingEntry() external view returns (int256 nextFundingEntry);

    function profitLoss(Position memory position, uint256 price) external view returns (int256 pnl);

    function profitLossTotal(uint256 price) external view returns (int256 pnl);

    function accruedFunding(Position memory position) external view returns (int256 accruedFunding);

    function accruedFundingTotalByLongs() external view returns (int256 accruedFundingLongs);

    function fundingAdjustedLongPnLTotal(
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (int256 fundingAdjustedPnL);

    function getCurrentSkew() external view returns (int256 skew);
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

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20Metadata.sol)

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

// src/interfaces/IStableModule.sol

interface IStableModule is IERC20Metadata {
    // solhint-disable-next-line func-name-mixedcase
    function MIN_LIQUIDITY() external view returns (uint32 minLiquidity);

    function executeDeposit(
        address account,
        uint64 executableAtTime,
        AnnouncedStableDeposit calldata announcedDeposit
    ) external;

    function executeWithdraw(
        address account,
        uint64 executableAtTime,
        AnnouncedStableWithdraw calldata announcedWithdraw
    ) external returns (uint256 amountOut, uint256 withdrawFee);

    function lock(address account, uint256 amount) external;

    function unlock(address account, uint256 amount) external;

    function stableCollateralTotalAfterSettlement() external view returns (uint256 stableCollateralBalance_);

    function stableCollateralTotalAfterSettlement(
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (uint256 stableCollateralBalance);

    function stableCollateralPerShare() external view returns (uint256 collateralPerShare);

    function stableCollateralPerShare(
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (uint256 collateralPerShare);

    function stableDepositQuote(uint256 depositAmount) external view returns (uint256 amountOut);

    function stableWithdrawQuote(
        uint256 withdrawAmount
    ) external view returns (uint256 amountOut, uint256 withdrawalFee);

    function getLockedAmount(address account) external view returns (uint256 amountLocked);
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

// src/interfaces/ILeverageModule.sol

interface ILeverageModule is IERC721Enumerable {
    function tokenIdNext() external view returns (uint256 tokenId);

    function marginMin() external view returns (uint256 marginMin);

    function leverageMin() external view returns (uint256 leverageMin);

    function leverageMax() external view returns (uint256 leverageMax);

    function executeOpen(address account, Order calldata order) external returns (uint256 tokenId);

    function executeAdjust(Order calldata order) external;

    function executeClose(Order calldata order) external returns (uint256 marginAfterPositionClose);

    function mint(address to) external returns (uint256 tokenId);

    function burn(uint256 tokenId) external;

    function getPositionSummary(uint256 tokenId) external view returns (PositionSummary memory positionSummary);

    function getPositionSummary(
        Position memory position,
        uint256 price
    ) external view returns (PositionSummary memory positionSummary);

    function checkLeverageCriteria(uint256 margin, uint256 size) external view;
}

// src/interfaces/IOracleModule.sol

interface IOracleModule {
    function pythOracleContract() external view returns (IPyth oracleContractAddress);

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData) external payable;

    function getPrice(address asset) external view returns (uint256 price, uint256 timestamp);

    function getPrice(
        address asset,
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (uint256 price, uint256 timestamp);

    function getOracleData(address asset) external view returns (OracleData memory oracleData);

    function setOracles(
        address _asset,
        OnchainOracle calldata _onchainOracle,
        OffchainOracle calldata _offchainOracle
    ) external;

    function setMaxDiffPercent(address _asset, uint64 _maxDiffPercent) external;
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

// src/abstracts/ModuleUpgradeable.sol

/// @title ModuleUpgradeable
/// @author dHEDGE
/// @notice This is the base contract for all upgradeable modules in the Flatcoin system.
abstract contract ModuleUpgradeable is Initializable {
    //////////////////////////////////////////
    //               Errors                 //
    //////////////////////////////////////////

    error Paused(bytes32 moduleKey);
    error OnlyOwner(address msgSender);
    error ModuleKeyEmpty();

    //////////////////////////////////////////
    //                State                 //
    //////////////////////////////////////////

    /// @notice The bytes32 encoded key of the module.
    /// @dev Note that this shouldn't change ever for existing modules.
    ///      Due to this module being upgradeable, we can't use immutable here.
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public MODULE_KEY;

    /// @notice The FlatcoinVault contract referred to by all modules.
    /// @dev Contains all the module addresses, the state of the system and more.
    IFlatcoinVault public vault;

    //////////////////////////////////////////
    //               Modifiers              //
    //////////////////////////////////////////

    modifier onlyAuthorizedModule() {
        if (vault.isAuthorizedModule(msg.sender) == false) revert ICommonErrors.OnlyAuthorizedModule(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (vault.isModulePaused(MODULE_KEY)) revert Paused(MODULE_KEY);
        _;
    }

    modifier onlyOwner() {
        if (OwnableUpgradeable(address(vault)).owner() != msg.sender) revert OnlyOwner(msg.sender);
        _;
    }

    //////////////////////////////////////////
    //               Functions              //
    //////////////////////////////////////////

    /// @notice Setter for the vault contract.
    /// @dev Can be used in case FlatcoinVault ever changes.
    function setVault(IFlatcoinVault vault_) external onlyOwner {
        if (address(vault_) == address(0)) revert ICommonErrors.ZeroAddress("vault");

        vault = vault_;
    }

    /// @dev Function to initialize a module.
    /// @param moduleKey_ The bytes32 encoded key of the module.
    /// @param vault_ FlatcoinVault contract address.
    // solhint-disable-next-line func-name-mixedcase
    function __Module_init(bytes32 moduleKey_, IFlatcoinVault vault_) internal {
        if (moduleKey_ == bytes32("")) revert ModuleKeyEmpty();
        if (address(vault_) == address(0)) revert ICommonErrors.ZeroAddress("vault");

        MODULE_KEY = moduleKey_;
        vault = vault_;
    }

    uint256[48] private __gap;
}

// src/abstracts/OracleModifiers.sol

/// @title OracleModifiers
/// @author dHEDGE
/// @notice Contract containing necessary modifiers for Oracle related functions.
abstract contract OracleModifiers {
    /// @dev Important to use this modifier in functions which require the Pyth network price to be updated.
    ///      Otherwise, the invariant checks or any other logic which depends on the Pyth network price may not be correct.
    modifier updatePythPrice(
        IFlatcoinVault vault_,
        address sender_,
        bytes[] calldata priceUpdateData_
    ) {
        IOracleModule(vault_.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).updatePythPrice{value: msg.value}(
            sender_,
            priceUpdateData_
        );
        _;
    }
}

// src/abstracts/InvariantChecks.sol

/// @title InvariantChecks
/// @author dHEDGE
/// @notice Contract module for critical invariant checking on the protocol.
abstract contract InvariantChecks {
    using SignedMath for int256;
    using Math for uint256;
    using SafeCast for *;

    //////////////////////////////////////////
    //              Errors                  //
    //////////////////////////////////////////

    error InvariantViolation(string variableName);

    //////////////////////////////////////////
    //              Structs                 //
    //////////////////////////////////////////

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

    //////////////////////////////////////////
    //              Modifiers               //
    //////////////////////////////////////////

    /// @notice Invariant checks on order execution
    /// @dev Checks:
    ///      1. Collateral net: The vault collateral balance relative to tracked collateral on both stable LP and leverage side should not change
    ///      2. Stable collateral per share: Stable LP value per share should never decrease after order execution. It should only increase due to collected trading fees
    modifier orderInvariantChecks(IFlatcoinVault vault_) {
        IStableModule stableModule = IStableModule(vault_.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantOrder memory invariantBefore = InvariantOrder({
            collateralNet: _getCollateralNet(vault_),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        _;

        InvariantOrder memory invariantAfter = InvariantOrder({
            collateralNet: _getCollateralNet(vault_),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        uint256 errorMargin = vault_.maxDeltaError();

        _collateralNetBalanceRemainsUnchanged(
            invariantBefore.collateralNet,
            invariantAfter.collateralNet,
            int256(errorMargin)
        );

        _stableCollateralPerShareIncreasesOrRemainsUnchanged(
            stableModule.totalSupply(),
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );

        _globalAveragePriceIsNotNegative(vault_);
    }

    /// @notice Invariant checks on order liquidation
    /// @dev For liquidations, stableCollateralPerShare can decrease if the position is underwater.
    modifier liquidationInvariantChecks(IFlatcoinVault vault_, uint256 tokenId_) {
        IStableModule stableModule = IStableModule(vault_.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantLiquidation memory invariantBefore = InvariantLiquidation({
            collateralNet: _getCollateralNet(vault_),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: ILeverageModule(vault_.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY))
                .getPositionSummary(tokenId_)
                .marginAfterSettlement,
            liquidationFee: ILiquidationModule(vault_.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY))
                .getLiquidationFee(tokenId_)
        });

        _;

        InvariantLiquidation memory invariantAfter = InvariantLiquidation({
            collateralNet: _getCollateralNet(vault_),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: 0,
            liquidationFee: 0
        });

        uint256 errorMargin = vault_.maxDeltaError();

        _stableCollateralPerShareLiquidation(
            stableModule,
            invariantBefore.liquidationFee,
            invariantBefore.remainingMargin,
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );

        _collateralNetBalanceRemainsUnchanged(
            invariantBefore.collateralNet,
            invariantAfter.collateralNet,
            int256(errorMargin)
        );
        _globalAveragePriceIsNotNegative(vault_);
    }

    /// @dev Returns the difference between actual total collateral balance in the vault vs tracked collateral
    ///      Tracked collateral should be updated when depositing to stable LP (stableCollateralTotal) or
    ///      opening leveraged positions (marginDepositedTotal).
    function _getCollateralNet(IFlatcoinVault vault_) private view returns (int256 netCollateral_) {
        int256 collateralBalance = int256(vault_.collateral().balanceOf(address(vault_)));
        int256 trackedCollateral = int256(vault_.stableCollateralTotal()) +
            vault_.getGlobalPositions().marginDepositedTotal;

        if (collateralBalance < trackedCollateral) revert InvariantChecks.InvariantViolation("collateralNet1");

        return collateralBalance - trackedCollateral;
    }

    function _globalAveragePriceIsNotNegative(IFlatcoinVault vault_) private view {
        if (vault_.getGlobalPositions().averagePrice < 0)
            revert InvariantChecks.InvariantViolation("globalAveragePriceIsNotNegative");
    }

    /// @dev Collateral balance changes should match tracked collateral changes
    function _collateralNetBalanceRemainsUnchanged(
        int256 netBefore_,
        int256 netAfter_,
        int256 errorMargin_
    ) private pure {
        // This means we are ok with a small margin of error such that netAfter > netBefore but within an absolute error margin.
        if (netBefore_ > netAfter_ || netAfter_ > netBefore_ + errorMargin_)
            revert InvariantChecks.InvariantViolation("collateralNet2");
    }

    /// @dev Stable LPs should never lose value (can only gain on trading fees)
    /// @dev It's impractical and unnecessary to check the exact increase in stable collateral per share here
    ///      because it would require calculating fees for all trade types including limit orders.
    function _stableCollateralPerShareIncreasesOrRemainsUnchanged(
        uint256 totalSupply_,
        uint256 collateralPerShareBefore_,
        uint256 collateralPerShareAfter_
    ) private pure {
        // only allow a small 0.0001% change in stable collateral per share
        // This is due to rounding errors which are larger with smaller decimal collateral
        if (totalSupply_ > 0 && collateralPerShareAfter_ < collateralPerShareBefore_) {
            uint256 diff = collateralPerShareBefore_ - collateralPerShareAfter_;
            uint256 percentDiff = (diff * 1e18) / collateralPerShareBefore_;

            if (percentDiff > 0.0001e16) {
                revert InvariantChecks.InvariantViolation("stableCollateralPerShare");
            }
        }
    }

    /// @dev Stable LPs should be adjusted according to the liquidated position remaining margin and liquidation fee
    /// @dev Checks that stableCollateralPerShare stays within 0.0001% of expected change
    function _stableCollateralPerShareLiquidation(
        IStableModule stableModule_,
        uint256 liquidationFee_,
        int256 remainingMargin_,
        uint256 stableCollateralPerShareBefore_,
        uint256 stableCollateralPerShareAfter_
    ) private view {
        uint256 totalSupply = stableModule_.totalSupply();

        if (totalSupply == 0) return;

        int256 expectedStableCollateralPerShare;
        if (remainingMargin_ > 0) {
            if (remainingMargin_ > int256(liquidationFee_)) {
                // position is healthy and there is a keeper fee taken from the margin
                // evaluate exact increase in stable collateral
                expectedStableCollateralPerShare =
                    int256(stableCollateralPerShareBefore_) +
                    (((remainingMargin_ - int256(liquidationFee_)) * 1e18) / int256(totalSupply));
            } else {
                // position has less or equal margin than liquidation fee
                // all the margin will go to the keeper and no change in stable collateral
                if (stableCollateralPerShareBefore_ != stableCollateralPerShareAfter_)
                    revert InvariantChecks.InvariantViolation("stableCollateralPerShareLiquidation");

                return;
            }
        } else {
            // position is underwater and there is no keeper fee
            // evaluate exact decrease in stable collateral
            expectedStableCollateralPerShare =
                int256(stableCollateralPerShareBefore_) +
                ((remainingMargin_ * 1e18) / int256(totalSupply)); // underwater margin per share
        }

        uint256 diff = (stableCollateralPerShareAfter_.toInt256() - expectedStableCollateralPerShare).abs();
        uint256 percentDiff = (diff * 1e18) / expectedStableCollateralPerShare.toUint256();

        if (percentDiff > 0.0001e16) {
            revert InvariantChecks.InvariantViolation("stableCollateralPerShareLiquidation");
        }
    }
}

// src/OrderExecutionModule.sol

/// @title OrderExecutionModule
/// @author dHEDGE
/// @notice Contract for executing delayed orders.
contract OrderExecutionModule is
    IOrderExecutionModule,
    ModuleUpgradeable,
    ReentrancyGuardUpgradeable,
    InvariantChecks,
    OracleModifiers
{
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IStableModule;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event OrderCancelled(address account, OrderType orderType);
    event OrderExecuted(address account, OrderType orderType, uint256 keeperFee);
    event LimitOrderExecuted(uint256 tokenId, LimitOrderExecutionType executionType);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error OrderHasExpired();
    error OrderHasNotExpired();
    error OrderInvalid(address account);
    error LimitOrderPriceNotInRange(uint256 price, uint256 stopLossPrice, uint256 profitTakePrice);

    /////////////////////////////////////////////
    //              Enums & Structs            //
    /////////////////////////////////////////////

    enum LimitOrderExecutionType {
        None, // 0
        StopLoss, // 1
        ProfitTake // 2
    }

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    /// @notice The maximum amount of time that can expire between trade announcement and execution.
    uint64 public maxExecutabilityAge;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the OrderExecutionModule with the Vault address.
    /// @param vault_ The address of the FlatcoinVault contract.
    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function initialize(IFlatcoinVault vault_, uint64 maxExecutabilityAge_) external initializer {
        __Module_init(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY, vault_);
        __ReentrancyGuard_init();

        _setMaxExecutabilityAge(maxExecutabilityAge_);
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    /// @notice Executes any valid pending order for an account.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending deposit.
    /// @param priceUpdateData_ The Pyth network offchain price oracle update data.
    function executeOrder(
        address account_,
        bytes[] calldata priceUpdateData_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updatePythPrice(vault, msg.sender, priceUpdateData_)
        orderInvariantChecks(vault)
    {
        Order memory order = _getAnnouncedOrder(account_);

        if (order.orderType == OrderType.None) revert OrderInvalid(account_);

        _prepareExecutionOrder(account_, order.executableAtTime);

        // Settle funding fees before executing any order.
        // This is to avoid error related to max caps or max skew reached when the market has been skewed to one side for a long time.
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        vault.checkGlobalMarginPositive();

        if (order.orderType == OrderType.StableDeposit) {
            _executeStableDeposit(account_, order);
        } else if (order.orderType == OrderType.StableWithdraw) {
            _executeStableWithdraw(account_, order);
        } else if (order.orderType == OrderType.LeverageOpen) {
            _executeLeverageOpen(account_, order);
        } else if (order.orderType == OrderType.LeverageClose) {
            _executeLeverageClose(account_, order);
        } else if (order.orderType == OrderType.LeverageAdjust) {
            _executeLeverageAdjust(account_, order);
        }

        emit OrderExecuted({account: account_, orderType: order.orderType, keeperFee: order.keeperFee});
    }

    /// @notice Function to execute a limit order
    /// @dev This function is typically called by the keeper
    /// @param tokenId_ The token ID of the leverage position.
    /// @param priceUpdateData_ The Pyth network offchain price oracle update data.
    function executeLimitOrder(
        uint256 tokenId_,
        bytes[] calldata priceUpdateData_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updatePythPrice(vault, msg.sender, priceUpdateData_)
        orderInvariantChecks(vault)
    {
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        vault.checkGlobalMarginPositive();

        Order memory order = _validateAndModifyLimitCloseOrder(tokenId_);

        _executeLeverageClose(
            ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).ownerOf(tokenId_),
            order
        );
    }

    /// @notice Function to cancel an existing order after it has expired.
    /// @dev This function can be called by anyone.
    /// @param account_ The user account which has a pending order.
    function cancelExistingOrder(address account_) external {
        Order memory order = _getAnnouncedOrder(account_);

        // If there is no order in store, just return.
        if (order.orderType == OrderType.None) return;

        if (block.timestamp <= order.executableAtTime + maxExecutabilityAge) revert OrderHasNotExpired();

        _cancelOrder(account_, order);
    }

    /// @notice Function to cancel an existing order by a module.
    /// @param account_ The user account which has a pending order.
    function cancelOrderByModule(address account_) external override onlyAuthorizedModule {
        _cancelOrder(account_, _getAnnouncedOrder(account_));
    }

    /////////////////////////////////////////////
    //              View Functions             //
    /////////////////////////////////////////////

    /// @notice Checks whether a user announced order has expired executability time or not
    /// @param account_ The user account which has a pending order
    /// @return expired_ True if the order has expired, false otherwise
    function hasOrderExpired(address account_) public view returns (bool expired_) {
        uint256 executableAtTime = _getAnnouncedOrder(account_).executableAtTime;

        if (executableAtTime <= 0) revert ICommonErrors.ZeroValue("executableAtTime");

        expired_ = (executableAtTime + maxExecutabilityAge >= block.timestamp) ? false : true;
    }

    /////////////////////////////////////////////
    //       Internal Execution Functions      //
    /////////////////////////////////////////////

    /// @notice User delayed deposit into the stable LP. Mints ERC20 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending deposit.
    function _executeStableDeposit(address account_, Order memory order_) internal {
        AnnouncedStableDeposit memory stableDeposit = abi.decode(order_.orderData, (AnnouncedStableDeposit));

        vault.checkCollateralCap(stableDeposit.depositAmount);

        IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)).executeDeposit(
            account_,
            order_.executableAtTime,
            stableDeposit
        );

        // Collateral and fees settlement.
        {
            vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee}); // pay the keeper their fee
            vault.collateral().safeTransfer({to: address(vault), value: stableDeposit.depositAmount}); // transfer collateral to the vault
        }
    }

    /// @notice User delayed withdrawal from the stable LP.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending withdrawal.
    function _executeStableWithdraw(address account_, Order memory order_) internal {
        AnnouncedStableWithdraw memory stableWithdraw = abi.decode(order_.orderData, (AnnouncedStableWithdraw));

        (uint256 amountOut, uint256 withdrawFee) = IStableModule(
            vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)
        ).executeWithdraw(account_, order_.executableAtTime, stableWithdraw);

        uint256 totalFee = order_.keeperFee + withdrawFee;

        // Make sure there is enough margin in the position to pay the keeper fee and withdrawal fee
        if (amountOut < totalFee) revert ICommonErrors.NotEnoughMarginForFees(int256(amountOut), totalFee);

        // include the fees here to check for slippage
        amountOut -= totalFee;

        if (amountOut < stableWithdraw.minAmountOut)
            revert ICommonErrors.HighSlippage(amountOut, stableWithdraw.minAmountOut);

        uint256 protocolFee = FeeManager(address(vault)).getProtocolFee(withdrawFee);

        // Collateral and fees settlement.
        {
            vault.updateStableCollateralTotal(int256(withdrawFee - protocolFee)); // pay the withdrawal fee to stable LPs
            vault.sendCollateral({to: FeeManager(address(vault)).protocolFeeRecipient(), amount: protocolFee}); // pay the protocol fee
            vault.sendCollateral({to: msg.sender, amount: order_.keeperFee}); // pay the keeper their fee
            vault.sendCollateral({to: account_, amount: amountOut}); // transfer remaining amount to the trader
        }
    }

    /// @notice Execution of user delayed leverage open order. Mints ERC721 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageOpen(address account_, Order memory order_) internal {
        AnnouncedLeverageOpen memory announcedOpen = abi.decode(order_.orderData, (AnnouncedLeverageOpen));

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(announcedOpen.tradeFee);
        uint256 adjustedTradeFee = announcedOpen.tradeFee - protocolFeePortion;

        // Check that the creation of this position doesn't exceed the global leverage cap.
        vault.checkSkewMax({
            sizeChange: announcedOpen.additionalSize,
            stableCollateralChange: int256(adjustedTradeFee)
        });

        uint256 newTokenId = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).executeOpen({
            account: account_,
            order: order_
        });

        // Create a limit order if the user has specified valid price thresholds.
        if (announcedOpen.stopLossPrice > 0 || announcedOpen.profitTakePrice < type(uint256).max) {
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .createLimitOrder({
                    positionOwner: account_,
                    tokenId: newTokenId,
                    stopLossPrice: announcedOpen.stopLossPrice,
                    profitTakePrice: announcedOpen.profitTakePrice
                });
        }

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Transfer the protocol fee portion of the trade fee to the protocol fee recipient.
            vault.collateral().safeTransfer({
                to: FeeManager(address(vault)).protocolFeeRecipient(),
                value: protocolFeePortion
            });

            // Transfer collateral + fees to the vault
            vault.collateral().safeTransfer({to: address(vault), value: announcedOpen.margin + adjustedTradeFee});

            // Pay the keeper their fee.
            vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee});
        }
    }

    /// @notice Execution of user delayed leverage adjust order.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageAdjust(address account_, Order memory order_) internal {
        AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(order_.orderData, (AnnouncedLeverageAdjust));

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        // Check that position exists (ownerOf reverts if owner is null address)
        // There is a possibility that position was deleted by liquidation or limit order module
        leverageModule.ownerOf(leverageAdjust.tokenId);

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(leverageAdjust.tradeFee);
        uint256 adjustedTradeFee = leverageAdjust.tradeFee - protocolFeePortion;

        if (leverageAdjust.additionalSizeAdjustment > 0) {
            // Given that the size of a position is being increased, it's necessary to check that
            // it doesn't exceed the max skew limit.
            vault.checkSkewMax({
                sizeChange: uint256(leverageAdjust.additionalSizeAdjustment),
                stableCollateralChange: int256(adjustedTradeFee)
            });
        }

        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
            .resetExecutionTime(leverageAdjust.tokenId);

        leverageModule.executeAdjust(order_);

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Margin adjustment amount, trade fee and keeper fee are present in this module.
            // Send the margin and adjusted fees to the vault.
            if (leverageAdjust.marginAdjustment > 0) {
                // Transfer the protocol fee portion of the trade fee to the protocol fee recipient.
                vault.collateral().safeTransfer({
                    to: FeeManager(address(vault)).protocolFeeRecipient(),
                    value: protocolFeePortion
                });

                // Transfer collateral + fees to the vault
                vault.collateral().safeTransfer({
                    to: address(vault),
                    value: uint256(leverageAdjust.marginAdjustment) + adjustedTradeFee
                });

                // Pay the keeper their fee.
                vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee});
            } else {
                if (leverageAdjust.marginAdjustment < 0) {
                    // We send the user that much margin they requested during announceLeverageAdjust().
                    // However their remaining margin is reduced by the fees.
                    // It is accounted in announceLeverageAdjust().
                    vault.sendCollateral({to: account_, amount: uint256(leverageAdjust.marginAdjustment * -1)});
                }

                // Send the keeper fee from the vault to the keeper.
                vault.sendCollateral({to: msg.sender, amount: order_.keeperFee});

                // Send the protocol fee portion from the vault to the protocol fee recipient.
                vault.sendCollateral({
                    to: FeeManager(address(vault)).protocolFeeRecipient(),
                    amount: protocolFeePortion
                });
            }
        }
    }

    /// @notice Execution of user delayed leverage close order. Burns ERC721 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageClose(address account_, Order memory order_) internal {
        AnnouncedLeverageClose memory leverageClose = abi.decode(order_.orderData, (AnnouncedLeverageClose));

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(leverageClose.tradeFee);
        uint256 adjustedTradeFee = leverageClose.tradeFee - protocolFeePortion;

        // Check that position exists (ownerOf reverts if owner is null address)
        // There is a possibility that position was deleted by liquidation or limit order module
        leverageModule.ownerOf(leverageClose.tokenId);
        uint256 marginAfterPositionClose = leverageModule.executeClose(order_);

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Fees are paid from the remaining position margin.
            vault.sendCollateral({to: FeeManager(address(vault)).protocolFeeRecipient(), amount: protocolFeePortion});
            vault.sendCollateral({to: msg.sender, amount: order_.keeperFee});

            // Transfer the settled margin minus fee from the vault to the trader.
            vault.sendCollateral({
                to: account_,
                amount: marginAfterPositionClose - leverageClose.tradeFee - order_.keeperFee
            });
        }
    }

    function _cancelOrder(address account_, Order memory order_) internal {
        // Delete the order tracker from storage.
        // NOTE: This is done before the transfer of ERC721 NFT to prevent reentrancy attacks.
        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)).deleteOrder(
            account_
        );

        if (order_.orderType == OrderType.StableDeposit) {
            AnnouncedStableDeposit memory stableDeposit = abi.decode(order_.orderData, (AnnouncedStableDeposit));

            // Send collateral back to trader
            vault.collateral().safeTransfer({to: account_, value: stableDeposit.depositAmount + order_.keeperFee});
        } else if (order_.orderType == OrderType.StableWithdraw) {
            AnnouncedStableWithdraw memory stableWithdraw = abi.decode(order_.orderData, (AnnouncedStableWithdraw));

            // Unlock the LP tokens belonging to this position which were locked during announcement.
            IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)).unlock({
                account: account_,
                amount: stableWithdraw.withdrawAmount
            });
        } else if (order_.orderType == OrderType.LeverageOpen) {
            AnnouncedLeverageOpen memory leverageOpen = abi.decode(order_.orderData, (AnnouncedLeverageOpen));

            // Send collateral back to trader
            vault.collateral().safeTransfer({
                to: account_,
                value: order_.keeperFee + leverageOpen.margin + leverageOpen.tradeFee
            });
        } else if (order_.orderType == OrderType.LeverageAdjust) {
            AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(order_.orderData, (AnnouncedLeverageAdjust));

            if (leverageAdjust.marginAdjustment > 0) {
                vault.collateral().safeTransfer({
                    to: account_,
                    value: uint256(leverageAdjust.marginAdjustment) + leverageAdjust.totalFee
                });
            }
        }

        emit OrderCancelled({account: account_, orderType: order_.orderType});
    }

    /// @dev This function HAS to be called before or as soon as the transaction flow enters an execute function.
    /// @param account_ The user account which has a pending order.
    /// @param executableAtTime_ The time at which the order can be executed.
    function _prepareExecutionOrder(address account_, uint256 executableAtTime_) internal {
        if (block.timestamp > executableAtTime_ + maxExecutabilityAge) revert OrderHasExpired();

        // Check that the minimum time delay is reached before execution
        if (block.timestamp < executableAtTime_) revert ICommonErrors.ExecutableTimeNotReached(executableAtTime_);

        // Delete the order tracker from storage.
        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)).deleteOrder(
            account_
        );
    }

    /// @param tokenId_ The token ID of the leverage position.
    function _validateAndModifyLimitCloseOrder(uint256 tokenId_) internal returns (Order memory order_) {
        IOrderAnnouncementModule orderAnnouncementModule = IOrderAnnouncementModule(
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
        );
        order_ = orderAnnouncementModule.getLimitOrder(tokenId_);

        if (order_.orderType != OrderType.LimitClose) revert OrderInvalid(address(uint160(tokenId_)));

        AnnouncedLimitClose memory limitOrder = abi.decode(order_.orderData, (AnnouncedLimitClose));

        (uint256 price, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            asset: address(vault.collateral()),
            maxAge: 86_400,
            priceDiffCheck: true
        });

        // Check that the minimum time delay is reached before execution
        if (block.timestamp < order_.executableAtTime)
            revert ICommonErrors.ExecutableTimeNotReached(order_.executableAtTime);

        uint256 minFillPrice;
        if (price <= limitOrder.stopLossPrice) {
            minFillPrice = 0; // can execute below lower limit price threshold
        } else if (price >= limitOrder.profitTakePrice) {
            minFillPrice = limitOrder.profitTakePrice;
        } else {
            revert LimitOrderPriceNotInRange(price, limitOrder.stopLossPrice, limitOrder.profitTakePrice);
        }

        order_.orderData = abi.encode(
            AnnouncedLeverageClose({
                tokenId: tokenId_,
                minFillPrice: minFillPrice,
                tradeFee: FeeManager(address(vault)).getTradeFee(vault.getPosition(tokenId_).additionalSize)
            })
        );

        order_.keeperFee = IKeeperFee(vault.moduleAddress(FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY)).getKeeperFee();

        // Delete the order tracker from storage.
        orderAnnouncementModule.deleteLimitOrder(tokenId_);

        // Emitting event here rather than in `executeLimitOrder` as the data is readily available.
        emit LimitOrderExecuted(
            tokenId_,
            (price <= limitOrder.stopLossPrice) ? LimitOrderExecutionType.StopLoss : LimitOrderExecutionType.ProfitTake
        );
    }

    /// @param account_ The user account which has a pending order.
    /// @return order_ The order struct.
    function _getAnnouncedOrder(address account_) private view returns (Order memory order_) {
        return
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .getAnnouncedOrder(account_);
    }

    /////////////////////////////////////////////
    //              Owner Functions            //
    /////////////////////////////////////////////

    /// @notice Setter for the maximum time delayed executatibility.
    /// @dev The maximum executability timer starts after the minimum time has elapsed.
    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function setMaxExecutabilityAge(uint64 maxExecutabilityAge_) external onlyOwner {
        _setMaxExecutabilityAge(maxExecutabilityAge_);
    }

    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function _setMaxExecutabilityAge(uint64 maxExecutabilityAge_) private {
        if (maxExecutabilityAge_ == 0) revert ICommonErrors.ZeroValue("maxExecutabilityAge");

        maxExecutabilityAge = maxExecutabilityAge_;
    }
}
