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

// lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
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

// src/interfaces/IPointsModule.sol

interface IPointsModule {
    struct MintPoints {
        address to;
        uint256 amount;
    }

    function getUnlockTax(address account) external view returns (uint256 unlockTax);

    function lockedBalance(address account) external view returns (uint256 amount);

    function mintDeposit(address to, uint256 depositAmount) external;

    function mintLeverageOpen(address to, uint256 size) external;

    function mintTo(MintPoints memory _mintPoints) external;

    function mintToMultiple(MintPoints[] memory _mintPoints) external;

    function pointsPerDeposit() external view returns (uint256 depositPoints);

    function pointsPerSize() external view returns (uint256 sizePoints);

    function setPointsVest(uint256 _unlockTaxVest, uint256 _pointsPerSize, uint256 _pointsPerDeposit) external;

    function setTreasury(address _treasury) external;

    function treasury() external view returns (address treasury);

    function unlock(uint256 amount) external;

    function unlockAll() external;

    function unlockTaxVest() external view returns (uint256 unlockTaxVest);

    function unlockTime(address account) external view returns (uint256 unlockTime);
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

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;
        mapping(address account => mapping(address spender => uint256)) _allowances;
        uint256 _totalSupply;
        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// src/libraries/FlatcoinEvents.sol

library FlatcoinEvents {
    event FundingFeesSettled(int256 settledFundingFee);

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

    function settleFundingFees() external;

    function getCurrentFundingRate() external view returns (int256 fundingRate);

    function getPosition(uint256 _tokenId) external view returns (FlatcoinStructs.Position memory position);

    function checkSkewMax(uint256 sizeChange, int256 stableCollateralChange) external view;

    function checkCollateralCap(uint256 depositAmount) external view;

    function checkGlobalMarginPositive() external view;

    function stableCollateralCap() external view returns (uint256 collateralCap);

    function getCurrentSkew() external view returns (int256 skew);
}

// src/misc/ERC20LockableUpgradeable.sol

// solhint-disable reason-string
// solhint-disable gas-custom-errors
contract ERC20LockableUpgradeable is ERC20Upgradeable {
    mapping(address account => uint256 lockedAmount) internal _lockedAmount;

    event Locked(address indexed account, uint256 amount);
    event Unlocked(address indexed account, uint256 amount);

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20LockableUpgradeable_init()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20LockableUpgradeable_init_unchained()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    function _lock(address account, uint256 amount) internal virtual {
        require(
            _lockedAmount[account] + amount <= balanceOf(account),
            "ERC20LockableUpgradeable: locked amount exceeds balance"
        );

        _lockedAmount[account] += amount;
        emit Locked(account, amount);
    }

    function _unlock(address account, uint256 amount) internal virtual {
        require(_lockedAmount[account] >= amount, "ERC20LockableUpgradeable: requested unlock exceeds locked balance");

        _lockedAmount[account] -= amount;

        emit Unlocked(account, amount);
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        // Make sure the sender has enough unlocked tokens.
        // Note: the below requirement is not needed when minting tokens in which case the `from` address is 0x0.
        if (from != address(0)) {
            require(
                balanceOf(from) - _lockedAmount[from] >= amount,
                "ERC20LockableUpgradeable: insufficient unlocked balance"
            );
        }

        super._update(from, to, amount);
    }

    uint256[49] private __gap;
}

// src/interfaces/IStableModule.sol

interface IStableModule is IERC20Metadata {
    function stableCollateralPerShare() external view returns (uint256 collateralPerShare);

    function executeDeposit(
        address account,
        uint64 executableAtTime,
        FlatcoinStructs.AnnouncedStableDeposit calldata announcedDeposit
    ) external;

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
    function executeOpen(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function executeAdjust(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function executeClose(address account, address keeper, FlatcoinStructs.Order calldata order) external;

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

// src/StableModule.sol

/// @title StableModule
/// @author dHEDGE
/// @notice Contains functions to handle stable LP deposits and withdrawals.
contract StableModule is IStableModule, ModuleUpgradeable, ERC20LockableUpgradeable {
    using SafeCast for *;
    using PerpMath for int256;
    using PerpMath for uint256;

    uint256 public constant MIN_LIQUIDITY = 10_000; // minimum totalSupply that is allowable

    /// @notice Fee for stable LP redemptions.
    /// @dev 1e18 = 100%
    uint256 public stableWithdrawFee;

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    function initialize(IFlatcoinVault _vault, uint256 _stableWithdrawFee) external initializer {
        __Module_init(FlatcoinModuleKeys._STABLE_MODULE_KEY, _vault);
        __ERC20_init("Flat Money", "UNIT");

        setStableWithdrawFee(_stableWithdrawFee);
    }

    /////////////////////////////////////////////
    //         External Write Functions        //
    /////////////////////////////////////////////

    /// @notice User delayed deposit into the stable LP. Mints ERC20 token receipt.
    /// @dev Needs to be used in conjunction with DelayedOrder module.
    /// @param _account The usser account which has a pending deposit.
    /// @param _executableAtTime The time at which the order can be executed.
    /// @param _announcedDeposit The pending order.
    function executeDeposit(
        address _account,
        uint64 _executableAtTime,
        FlatcoinStructs.AnnouncedStableDeposit calldata _announcedDeposit
    ) external onlyAuthorizedModule {
        uint256 depositAmount = _announcedDeposit.depositAmount;

        uint32 maxAge = _getMaxAge(_executableAtTime);

        uint256 liquidityMinted = (depositAmount * (10 ** decimals())) /
            stableCollateralPerShare({_maxAge: maxAge, _priceDiffCheck: true});

        if (liquidityMinted < _announcedDeposit.minAmountOut)
            revert FlatcoinErrors.HighSlippage(liquidityMinted, _announcedDeposit.minAmountOut);

        _mint(_account, liquidityMinted);

        vault.updateStableCollateralTotal(int256(depositAmount));

        if (totalSupply() < MIN_LIQUIDITY)
            revert FlatcoinErrors.AmountTooSmall({amount: totalSupply(), minAmount: MIN_LIQUIDITY});

        // Mint points
        IPointsModule pointsModule = IPointsModule(vault.moduleAddress(FlatcoinModuleKeys._POINTS_MODULE_KEY));
        pointsModule.mintDeposit(_account, _announcedDeposit.depositAmount);

        emit FlatcoinEvents.Deposit(_account, depositAmount, liquidityMinted);
    }

    /// @notice User delayed withdrawal from the stable LP. Burns ERC20 token receipt.
    /// @dev Needs to be used in conjunction with DelayedOrder module.
    /// @param _account The usser account which has a pending withdrawal.
    /// @param _executableAtTime The time at which the order can be executed.
    /// @param _announcedWithdraw The pending order.
    /// @return _amountOut The amount of collateral withdrawn.
    /// @return _withdrawFee The fee paid to the remaining LPs.
    function executeWithdraw(
        address _account,
        uint64 _executableAtTime,
        FlatcoinStructs.AnnouncedStableWithdraw calldata _announcedWithdraw
    ) external onlyAuthorizedModule returns (uint256 _amountOut, uint256 _withdrawFee) {
        uint256 withdrawAmount = _announcedWithdraw.withdrawAmount;

        uint32 maxAge = _getMaxAge(_executableAtTime);

        uint256 stableCollateralPerShareBefore = stableCollateralPerShare({_maxAge: maxAge, _priceDiffCheck: true});
        _amountOut = (withdrawAmount * stableCollateralPerShareBefore) / (10 ** decimals());

        // Unlock the locked LP tokens before burning.
        // This is because if the amount to be burned is locked, the burn will fail due to `_beforeTokenTransfer`.
        _unlock(_account, withdrawAmount);

        _burn(_account, withdrawAmount);

        vault.updateStableCollateralTotal(-int256(_amountOut));

        uint256 stableCollateralPerShareAfter = stableCollateralPerShare({_maxAge: maxAge, _priceDiffCheck: true});

        // Check that there is no significant impact on stable token price.
        // This should never happen and means that too much value or not enough value was withdrawn.
        if (totalSupply() > 0) {
            if (
                stableCollateralPerShareAfter < stableCollateralPerShareBefore - 1e6 ||
                stableCollateralPerShareAfter > stableCollateralPerShareBefore + 1e6
            ) revert FlatcoinErrors.PriceImpactDuringWithdraw();

            // Apply the withdraw fee if it's not the final withdrawal.
            _withdrawFee = (stableWithdrawFee * _amountOut) / 1e18;

            // additionalSkew = 0 because withdrawal was already processed above.
            vault.checkSkewMax({sizeChange: 0, stableCollateralChange: int256(_withdrawFee)});
        } else {
            // Need to check there are no longs open before allowing full system withdrawal.
            uint256 sizeOpenedTotal = vault.getVaultSummary().globalPositions.sizeOpenedTotal;

            if (sizeOpenedTotal != 0) revert FlatcoinErrors.MaxSkewReached(sizeOpenedTotal);
            if (stableCollateralPerShareAfter != 1e18) revert FlatcoinErrors.PriceImpactDuringFullWithdraw();
        }

        emit FlatcoinEvents.Withdraw(_account, _amountOut, withdrawAmount);
    }

    /// @notice Function to lock a certain amount of an account's LP tokens.
    /// @dev This function is used to lock LP tokens when an account announces a delayed order.
    /// @param _account The account to lock the LP tokens from.
    /// @param _amount The amount of LP tokens to lock.
    function lock(address _account, uint256 _amount) public onlyAuthorizedModule {
        _lock(_account, _amount);
    }

    /// @notice Function to unlock a certain amount of an account's LP tokens.
    /// @dev This function is used to unlock LP tokens when an account cancels a delayed order
    ///      or when an order is executed.
    /// @param _account The account to unlock the LP tokens from.
    /// @param _amount The amount of LP tokens to unlock.
    function unlock(address _account, uint256 _amount) public onlyAuthorizedModule {
        _unlock(_account, _amount);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Total collateral available for withdrawal.
    /// @dev Balance takes into account trader profit and loss and funding rate.
    /// @return _stableCollateralBalance The total collateral available for withdrawal.
    function stableCollateralTotalAfterSettlement() public view returns (uint256 _stableCollateralBalance) {
        return stableCollateralTotalAfterSettlement({_maxAge: type(uint32).max, _priceDiffCheck: false});
    }

    /// @notice Function to calculate total stable side collateral after accounting for trader profit and loss and funding fees.
    /// @param _maxAge The oldest price oracle timestamp that can be used. Set to 0 to ignore.
    /// @return _stableCollateralBalance The total collateral available for withdrawal.
    function stableCollateralTotalAfterSettlement(
        uint32 _maxAge,
        bool _priceDiffCheck
    ) public view returns (uint256 _stableCollateralBalance) {
        // Assumption => pnlTotal = pnlLong + fundingAccruedLong
        // The assumption is based on the fact that stable LPs are the counterparty to leverage traders.
        // If the `pnlLong` is +ve that means the traders won and the LPs lost between the last funding rate update and now.
        // Similary if the `fundingAccruedLong` is +ve that means the market was skewed short-side.
        // When we combine these two terms, we get the total profit/loss of the leverage traders.
        // NOTE: This function if called after settlement returns only the PnL as funding has already been adjusted
        //      due to calling `_settleFundingFees()`. Although this still means `netTotal` includes the funding
        //      adjusted long PnL, it might not be clear to the reader of the code.
        int256 netTotal = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY))
            .fundingAdjustedLongPnLTotal({maxAge: _maxAge, priceDiffCheck: _priceDiffCheck});

        // The flatcoin LPs are the counterparty to the leverage traders.
        // So when the traders win, the flatcoin LPs lose and vice versa.
        // Therefore we subtract the leverage trader profits and add the losses
        int256 totalAfterSettlement = int256(vault.stableCollateralTotal()) - netTotal;

        if (totalAfterSettlement < 0) {
            _stableCollateralBalance = 0;
        } else {
            _stableCollateralBalance = uint256(totalAfterSettlement);
        }
    }

    /// @notice Function to calculate the collateral per share.
    /// @return _collateralPerShare The collateral per share.
    function stableCollateralPerShare() public view returns (uint256 _collateralPerShare) {
        return stableCollateralPerShare({_maxAge: type(uint32).max, _priceDiffCheck: false});
    }

    /// @notice Function to calculate the collateral per share.
    /// @param _maxAge The oldest price oracle timestamp that can be used.
    /// @return _collateralPerShare The collateral per share.
    function stableCollateralPerShare(
        uint32 _maxAge,
        bool _priceDiffCheck
    ) public view returns (uint256 _collateralPerShare) {
        uint256 totalSupply = totalSupply();

        if (totalSupply > 0) {
            uint256 stableBalance = stableCollateralTotalAfterSettlement({
                _maxAge: _maxAge,
                _priceDiffCheck: _priceDiffCheck
            });
            _collateralPerShare = (stableBalance * (10 ** decimals())) / totalSupply;
        } else {
            // no shares have been minted yet
            _collateralPerShare = 1e18;
        }
    }

    /// @notice Quoter function for getting the stable deposit amount out.
    /// @param _depositAmount The amount of collateral to deposit.
    /// @return _amountOut The amount of LP tokens minted.
    function stableDepositQuote(uint256 _depositAmount) public view returns (uint256 _amountOut) {
        return (_depositAmount * (10 ** decimals())) / stableCollateralPerShare();
    }

    /// @notice Quoter function for getting the stable withdraw amount out.
    /// @param _withdrawAmount The amount of LP tokens to withdraw.
    /// @return _amountOut The amount of collateral withdrawn.
    function stableWithdrawQuote(uint256 _withdrawAmount) public view returns (uint256 _amountOut) {
        _amountOut = (_withdrawAmount * stableCollateralPerShare()) / (10 ** decimals());

        // Take out the withdrawal fee
        _amountOut -= (_amountOut * stableWithdrawFee) / 1e18;
    }

    /// @notice Function to get the locked amount of an account.
    /// @param _account The account to get the locked amount for.
    /// @return _amountLocked The amount of LP tokens locked.
    function getLockedAmount(address _account) public view returns (uint256 _amountLocked) {
        return _lockedAmount[_account];
    }

    /////////////////////////////////////////////
    //            Internal Functions           //
    /////////////////////////////////////////////

    /// @notice Returns the maximum age of the oracle price to be used.
    /// @param _executableAtTime The time at which the order is executable.
    /// @return _maxAge The maximum age of the oracle price to be used.
    function _getMaxAge(uint64 _executableAtTime) internal view returns (uint32 _maxAge) {
        return (block.timestamp - _executableAtTime).toUint32();
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Setter for the stable withdraw fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param _stableWithdrawFee The new stable withdraw fee.
    function setStableWithdrawFee(uint256 _stableWithdrawFee) public onlyOwner {
        // Set fee cap to max 1%.
        // This is to avoid fat fingering but if any change is needed, the owner needs to
        // upgrade this module.
        if (_stableWithdrawFee > 0.01e18) revert FlatcoinErrors.InvalidFee(_stableWithdrawFee);

        stableWithdrawFee = _stableWithdrawFee;
    }
}
