// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity =0.8.28 ^0.8.0 ^0.8.20 ^0.8.28;

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

// src/OrderAnnouncementModule.sol

/// @title OrderAnnouncementModule
/// @author dHEDGE
/// @notice Contains functions to announce delayed orders.
contract OrderAnnouncementModule is IOrderAnnouncementModule, ModuleUpgradeable {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IStableModule;

    /////////////////////////////////////////////
    //               Events                    //
    /////////////////////////////////////////////

    event LimitOrderCancelled(address account, uint256 tokenId);
    event OrderAnnounced(address account, OrderType orderType, uint256 keeperFee);
    event LimitOrderAnnounced(address account, uint256 tokenId, uint256 stopLossPrice, uint256 profitTakePrice);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error UnauthorizedReceiver(address account);
    error LimitOrderInvalid(uint256 tokenId);
    error OnlyAuthorizedCaller(address caller);
    error WithdrawalTooSmall(uint256 withdrawAmount, uint256 keeperFee);
    error MaxFillPriceTooLow(uint256 maxFillPrice, uint256 currentPrice);
    error MinFillPriceTooHigh(uint256 minFillPrice, uint256 currentPrice);
    error InvalidLimitOrderPrices(uint256 stopLossPrice, uint256 profitTakePrice);
    error NotEnoughBalanceForWithdraw(address account, uint256 totalBalance, uint256 withdrawAmount);

    /////////////////////////////////////////////
    //                  State                  //
    /////////////////////////////////////////////

    /// @notice Minimum deposit amount for stable LP collateral.
    /// @dev Includes 18 decimals.
    uint256 public minDepositAmountUSD;

    /// @notice The minimum time that needs to expire between trade announcement and execution.
    uint64 public minExecutabilityAge;

    /// @dev Mapping to check if a caller is whitelisted.
    ///      Used for checking if `announceXFor` functions can be called by a specific caller.
    mapping(address caller => bool authorized) public authorizedCallers;

    /// @dev Mapping containing all the orders in an encoded format.
    mapping(address account => Order order) private _announcedOrder;

    /// @dev Mapping containing all the limit orders in an encoded format.
    mapping(uint256 tokenId => Order order) private _limitOrder;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    /// @param minDepositAmountUSD_ The minimum deposit amount for minting the LP token. Should be in 18 decimals.
    /// @param minExecutabilityAge_ The minimum time that needs to expire between trade announcement and execution.
    function initialize(
        IFlatcoinVault vault_,
        uint128 minDepositAmountUSD_,
        uint64 minExecutabilityAge_
    ) external initializer {
        __Module_init(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY, vault_);

        _setMinExecutabilityAge(minExecutabilityAge_);
        minDepositAmountUSD = minDepositAmountUSD_;
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    /// @notice Announces deposit intent for keepers to execute at offchain oracle price.
    function announceStableDeposit(uint256 depositAmount_, uint256 minAmountOut_, uint256 keeperFee_) external {
        announceStableDepositFor({
            depositAmount_: depositAmount_,
            minAmountOut_: minAmountOut_,
            keeperFee_: keeperFee_,
            receiver_: msg.sender
        });
    }

    /// @notice Announces leverage open intent for keepers to execute at offchain oracle price.
    function announceLeverageOpen(
        uint256 margin_,
        uint256 additionalSize_,
        uint256 maxFillPrice_,
        uint256 keeperFee_
    ) external {
        announceLeverageOpenFor({
            margin_: margin_,
            additionalSize_: additionalSize_,
            maxFillPrice_: maxFillPrice_,
            stopLossPrice_: 0,
            profitTakePrice_: type(uint256).max,
            keeperFee_: keeperFee_,
            receiver_: msg.sender
        });
    }

    function announceLeverageOpenWithLimits(
        uint256 margin_,
        uint256 additionalSize_,
        uint256 maxFillPrice_,
        uint256 stopLossPrice_,
        uint256 profitTakePrice_,
        uint256 keeperFee_
    ) external {
        announceLeverageOpenFor({
            margin_: margin_,
            additionalSize_: additionalSize_,
            maxFillPrice_: maxFillPrice_,
            stopLossPrice_: stopLossPrice_,
            profitTakePrice_: profitTakePrice_,
            keeperFee_: keeperFee_,
            receiver_: msg.sender
        });
    }

    /// @notice Announces deposit intent on behalf of another account for keepers to execute at offchain oracle price.
    /// @dev The deposit amount is taken plus the keeper fee.
    /// @dev Can be announced for an account that is not the sender.
    /// @param depositAmount_ The amount of collateral to deposit.
    /// @param minAmountOut_ The minimum amount of tokens the user expects to receive back.
    /// @param keeperFee_ The fee the user is paying for keeper transaction execution (in collateral tokens).
    /// @param receiver_ The receiver address of the token received back.
    function announceStableDepositFor(
        uint256 depositAmount_,
        uint256 minAmountOut_,
        uint256 keeperFee_,
        address receiver_
    ) public whenNotPaused {
        if (receiver_ != msg.sender && !authorizedCallers[msg.sender]) revert OnlyAuthorizedCaller(msg.sender);

        IERC20Metadata collateral = vault.collateral();
        uint64 executableAtTime = _prepareAnnouncementOrder(keeperFee_, receiver_);

        vault.checkCollateralCap(depositAmount_);

        // Check for minimum deposit amount (in USD).
        {
            uint256 cachedminDepositAmountUSD = minDepositAmountUSD;
            (uint256 collateralPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
                .getPrice(address(collateral));
            uint256 depositAmountUSD = (depositAmount_ * collateralPrice) / (10 ** collateral.decimals());

            if (depositAmountUSD < cachedminDepositAmountUSD)
                revert ICommonErrors.AmountTooSmall({amount: depositAmountUSD, minAmount: cachedminDepositAmountUSD});
        }

        // Check that the requested minAmountOut is feasible
        uint256 quotedAmount = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY))
            .stableDepositQuote(depositAmount_);

        if (quotedAmount < minAmountOut_) revert ICommonErrors.HighSlippage(quotedAmount, minAmountOut_);

        _announcedOrder[receiver_] = Order({
            orderType: OrderType.StableDeposit,
            orderData: abi.encode(
                AnnouncedStableDeposit({
                    depositAmount: depositAmount_,
                    minAmountOut: minAmountOut_,
                    announcedBy: msg.sender
                })
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        // Sends collateral to the delayed order contract first before it is settled by keepers and sent to the vault
        collateral.safeTransferFrom(
            msg.sender,
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY),
            depositAmount_ + keeperFee_
        );

        emit OrderAnnounced({account: receiver_, orderType: OrderType.StableDeposit, keeperFee: keeperFee_});
    }

    /// @notice Announces withdrawal intent for keepers to execute at offchain oracle price.
    /// @dev The deposit amount is taken plus the keeper fee, also in LP tokens.
    /// @param withdrawAmount_ The amount to withdraw in stable LP tokens.
    /// @param minAmountOut_ The minimum amount of underlying asset tokens the user expects to receive back.
    /// @param keeperFee_ The fee the user is paying for keeper transaction execution (in stable LP tokens).
    function announceStableWithdraw(
        uint256 withdrawAmount_,
        uint256 minAmountOut_,
        uint256 keeperFee_
    ) external whenNotPaused {
        uint64 executableAtTime = _prepareAnnouncementOrder(keeperFee_, msg.sender);

        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));
        uint256 lpBalance = IERC20Metadata(stableModule).balanceOf(msg.sender);

        if (lpBalance < withdrawAmount_) revert NotEnoughBalanceForWithdraw(msg.sender, lpBalance, withdrawAmount_);

        // Check that the requested minAmountOut is feasible
        {
            (uint256 expectedAmountOut, uint256 withdrawalFee) = stableModule.stableWithdrawQuote(withdrawAmount_);

            // The withdrawal fee minus the protocol fee stays in the vault so account for that.
            vault.checkSkewMax({
                sizeChange: 0,
                stableCollateralChange: -int256(
                    expectedAmountOut + (FeeManager(address(vault)).getProtocolFee(withdrawalFee))
                )
            });

            if (keeperFee_ > expectedAmountOut) revert WithdrawalTooSmall(expectedAmountOut, keeperFee_);

            expectedAmountOut -= keeperFee_;

            if (expectedAmountOut < minAmountOut_) revert ICommonErrors.HighSlippage(expectedAmountOut, minAmountOut_);
        }

        _announcedOrder[msg.sender] = Order({
            orderType: OrderType.StableWithdraw,
            orderData: abi.encode(
                AnnouncedStableWithdraw({withdrawAmount: withdrawAmount_, minAmountOut: minAmountOut_})
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        // Lock the LP tokens belonging to this position so that it can't be transferred to someone else.
        // Locking doesn't require an approval from an account.
        stableModule.lock({account: msg.sender, amount: withdrawAmount_});

        emit OrderAnnounced({account: msg.sender, orderType: OrderType.StableWithdraw, keeperFee: keeperFee_});
    }

    /// @notice Announces leverage open intent on behalf of another account for keepers to execute at offchain oracle price.
    /// @dev Can be announced for an account that is not the sender.
    /// @param margin_ The amount of collateral to deposit.
    /// @param additionalSize_ The amount of additional size to open.
    /// @param maxFillPrice_ The maximum price at which the trade can be executed.
    /// @param stopLossPrice_ The price lower threshold for the limit order.
    /// @param profitTakePrice_ The price upper threshold for the limit order.
    /// @param keeperFee_ The fee the user is paying for keeper transaction execution (in collateral tokens).
    /// @param receiver_ The receiver address of the token received back.
    function announceLeverageOpenFor(
        uint256 margin_,
        uint256 additionalSize_,
        uint256 maxFillPrice_,
        uint256 stopLossPrice_,
        uint256 profitTakePrice_,
        uint256 keeperFee_,
        address receiver_
    ) public whenNotPaused {
        if (receiver_ != msg.sender && !authorizedCallers[msg.sender]) revert OnlyAuthorizedCaller(msg.sender);

        // Options market related checks.
        if (IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).CONTROLLER_TYPE() == 2) {
            if (vault.isMaxPositionsReached()) revert ICommonErrors.MaxPositionsReached();
            if (!vault.isPositionOpenWhitelisted(receiver_)) revert UnauthorizedReceiver(receiver_);
        }

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        uint64 executableAtTime = _prepareAnnouncementOrder(keeperFee_, receiver_);

        uint256 tradeFee = FeeManager(address(vault)).getTradeFee(additionalSize_);

        vault.checkSkewMax({
            sizeChange: additionalSize_,
            stableCollateralChange: int256(tradeFee - FeeManager(address(vault)).getProtocolFee(tradeFee))
        });

        leverageModule.checkLeverageCriteria(margin_, additionalSize_);

        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        if (maxFillPrice_ < currentPrice) revert MaxFillPriceTooLow(maxFillPrice_, currentPrice);

        if (
            ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)).getLiquidationMargin(
                additionalSize_,
                maxFillPrice_
            ) >= margin_
        ) revert ICommonErrors.PositionCreatesBadDebt();

        if (stopLossPrice_ >= profitTakePrice_) revert InvalidLimitOrderPrices(stopLossPrice_, profitTakePrice_);

        _announcedOrder[receiver_] = Order({
            orderType: OrderType.LeverageOpen,
            orderData: abi.encode(
                AnnouncedLeverageOpen({
                    margin: margin_,
                    additionalSize: additionalSize_,
                    maxFillPrice: maxFillPrice_,
                    tradeFee: tradeFee,
                    stopLossPrice: stopLossPrice_,
                    profitTakePrice: profitTakePrice_,
                    announcedBy: msg.sender
                })
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        // Sends collateral to the execution order contract first before it is settled by keepers and sent to the vault
        vault.collateral().safeTransferFrom(
            msg.sender,
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY),
            margin_ + keeperFee_ + tradeFee
        );

        emit OrderAnnounced({account: receiver_, orderType: OrderType.LeverageOpen, keeperFee: keeperFee_});
    }

    /// @notice Announces leverage adjust intent for keepers to execute at offchain oracle price.
    /// @param tokenId_ The ERC721 token ID of the position.
    /// @param marginAdjustment_ The amount of margin to deposit or withdraw.
    /// @param additionalSizeAdjustment_ The amount of additional size to increase or decrease.
    /// @param fillPrice_ The price at which the trade can be executed.
    /// @param keeperFee_ The fee the user is paying for keeper transaction execution (in collateral tokens).
    function announceLeverageAdjust(
        uint256 tokenId_,
        int256 marginAdjustment_,
        int256 additionalSizeAdjustment_,
        uint256 fillPrice_,
        uint256 keeperFee_
    ) external whenNotPaused {
        uint64 executableAtTime = _prepareAnnouncementOrder(keeperFee_, msg.sender);

        // If both adjustable parameters are zero, there is nothing to adjust
        if (marginAdjustment_ == 0 && additionalSizeAdjustment_ == 0)
            revert ICommonErrors.ZeroValue("marginAdjustment|additionalSizeAdjustment");

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        // Check that the caller is the owner of the token
        if (leverageModule.ownerOf(tokenId_) != msg.sender) revert ICommonErrors.NotTokenOwner(tokenId_, msg.sender);

        // Trade fee is calculated based on additional size change
        uint256 totalFee;
        {
            uint256 tradeFee;
            (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
                .getPrice(address(vault.collateral()));

            // Means increasing or decreasing additional size
            if (additionalSizeAdjustment_ >= 0) {
                // If additionalSizeAdjustment equals zero, trade fee is zero as well
                // and no need to check for skew max.
                if (additionalSizeAdjustment_ > 0) {
                    tradeFee = FeeManager(address(vault)).getTradeFee(uint256(additionalSizeAdjustment_));
                    vault.checkSkewMax({
                        sizeChange: uint256(additionalSizeAdjustment_),
                        stableCollateralChange: int256(tradeFee - FeeManager(address(vault)).getProtocolFee(tradeFee))
                    });
                }

                if (fillPrice_ < currentPrice) revert MaxFillPriceTooLow(fillPrice_, currentPrice);
            } else {
                tradeFee = FeeManager(address(vault)).getTradeFee(uint256(additionalSizeAdjustment_ * -1));

                if (fillPrice_ > currentPrice) revert MinFillPriceTooHigh(fillPrice_, currentPrice);
            }

            totalFee = tradeFee + keeperFee_;
        }

        {
            // New additional size will be either bigger or smaller than current additional size
            // depends on if additionalSizeAdjustment is positive or negative.
            int256 newAdditionalSize = int256(vault.getPosition(tokenId_).additionalSize) + additionalSizeAdjustment_;

            // If user withdraws margin or changes additional size with no changes to margin, fees are charged from their existing margin.
            int256 newMarginAfterSettlement = leverageModule.getPositionSummary(tokenId_).marginAfterSettlement +
                ((marginAdjustment_ > 0) ? marginAdjustment_ : marginAdjustment_ - int256(totalFee));

            // New margin or size can't be negative, which means that they want to withdraw more than they deposited or not enough to pay the fees
            if (newMarginAfterSettlement < 0 || newAdditionalSize < 0)
                revert ICommonErrors.ValueNotPositive("newMarginAfterSettlement|newAdditionalSize");

            if (
                ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY))
                    .getLiquidationMargin(uint256(newAdditionalSize), fillPrice_) >= uint256(newMarginAfterSettlement)
            ) revert ICommonErrors.PositionCreatesBadDebt();

            // New values can't be less than min margin and min/max leverage requirements.
            leverageModule.checkLeverageCriteria(uint256(newMarginAfterSettlement), uint256(newAdditionalSize));
        }

        _announcedOrder[msg.sender] = Order({
            orderType: OrderType.LeverageAdjust,
            orderData: abi.encode(
                AnnouncedLeverageAdjust({
                    tokenId: tokenId_,
                    marginAdjustment: marginAdjustment_,
                    additionalSizeAdjustment: additionalSizeAdjustment_,
                    fillPrice: fillPrice_,
                    tradeFee: totalFee - keeperFee_,
                    totalFee: totalFee
                })
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        // If user increases margin, fees are charged from their account.
        if (marginAdjustment_ > 0) {
            // Sending positive margin adjustment and both fees from the user to the delayed order contract.
            vault.collateral().safeTransferFrom(
                msg.sender,
                vault.moduleAddress(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY),
                uint256(marginAdjustment_) + totalFee
            );
        }

        emit OrderAnnounced({account: msg.sender, orderType: OrderType.LeverageAdjust, keeperFee: keeperFee_});
    }

    /// @notice Announces leverage close intent for keepers to execute at offchain oracle price.
    /// @param tokenId_ The ERC721 token ID of the position.
    /// @param minFillPrice_ The minimum price at which the trade can be executed.
    /// @param keeperFee_ The fee the user is paying for keeper transaction execution (in collateral tokens).
    function announceLeverageClose(uint256 tokenId_, uint256 minFillPrice_, uint256 keeperFee_) external whenNotPaused {
        uint64 executableAtTime = _prepareAnnouncementOrder(keeperFee_, msg.sender);
        uint256 tradeFee;

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        // Check that the caller of this function is actually the owner of the token ID.
        if (leverageModule.ownerOf(tokenId_) != msg.sender) revert ICommonErrors.NotTokenOwner(tokenId_, msg.sender);

        {
            uint256 size = vault.getPosition(tokenId_).additionalSize;

            // Position needs additional margin to cover the trading fee on closing the position
            tradeFee = FeeManager(address(vault)).getTradeFee(size);

            // Make sure there is enough margin in the position to pay the keeper fee and trading fee
            // This should always pass because the position should get liquidated before the margin becomes too small
            int256 settledMargin = leverageModule.getPositionSummary(tokenId_).marginAfterSettlement;

            uint256 totalFee = tradeFee + keeperFee_;
            if (settledMargin < int256(totalFee)) revert ICommonErrors.NotEnoughMarginForFees(settledMargin, totalFee);

            (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
                .getPrice(address(vault.collateral()));

            if (minFillPrice_ > currentPrice) revert MinFillPriceTooHigh(minFillPrice_, currentPrice);
        }

        _announcedOrder[msg.sender] = Order({
            orderType: OrderType.LeverageClose,
            orderData: abi.encode(
                AnnouncedLeverageClose({tokenId: tokenId_, minFillPrice: minFillPrice_, tradeFee: tradeFee})
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        emit OrderAnnounced({account: msg.sender, orderType: OrderType.LeverageClose, keeperFee: keeperFee_});
    }

    /// @notice Announces a limit order to close a position at a specific price.
    ///         If a user doesn't want to set `stopLossPrice_` or `profitTakePrice_`, they can set them to 0 or `type(uint256).max` respectively.
    /// @param tokenId_ The ERC721 token ID of the position.
    /// @param stopLossPrice_ The 18 decimal price at which the position should be closed to prevent further losses.
    /// @param profitTakePrice_ The 18 decimal price at which the position should be closed to take profit.
    function announceLimitOrder(uint256 tokenId_, uint256 stopLossPrice_, uint256 profitTakePrice_) external {
        if (
            ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).ownerOf(tokenId_) !=
            msg.sender
        ) revert ICommonErrors.NotTokenOwner(tokenId_, msg.sender);

        _createLimitOrder({
            tokenId_: tokenId_,
            positionOwner_: msg.sender,
            stopLossPrice_: stopLossPrice_,
            profitTakePrice_: profitTakePrice_
        });
    }

    /// @notice Cancels a limit order by the position owner.
    /// @param tokenId_ The ERC721 token ID of the position.
    function cancelLimitOrder(uint256 tokenId_) external {
        if (
            ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).ownerOf(tokenId_) !=
            msg.sender
        ) revert ICommonErrors.NotTokenOwner(tokenId_, msg.sender);

        if (_limitOrder[tokenId_].orderType == OrderType.None) revert LimitOrderInvalid(tokenId_);

        _deleteLimitOrder(tokenId_);
    }

    /////////////////////////////////////////////
    //       Authorized Module Functions       //
    /////////////////////////////////////////////

    /// @notice Function to allow creation of limit orders by authorized modules.
    /// @param tokenId_ The ERC721 token ID of the position.
    /// @param positionOwner_ The owner of the position.
    /// @param stopLossPrice_ The 18 decimal price at which the position should be closed to prevent further losses.
    /// @param profitTakePrice_ The 18 decimal price at which the position should be closed to take profit.
    function createLimitOrder(
        uint256 tokenId_,
        address positionOwner_,
        uint256 stopLossPrice_,
        uint256 profitTakePrice_
    ) external onlyAuthorizedModule {
        _createLimitOrder({
            positionOwner_: positionOwner_,
            tokenId_: tokenId_,
            stopLossPrice_: stopLossPrice_,
            profitTakePrice_: profitTakePrice_
        });
    }

    /// @notice Updates the execution time of a limit order. Called when the position is adjusted.
    /// @dev It ensures that a limit order cannot be closed immediately after adjusting a position
    ///      This prevents price frontrunning scenarios
    function resetExecutionTime(uint256 tokenId_) external onlyAuthorizedModule {
        if (_limitOrder[tokenId_].orderType == OrderType.LimitClose) {
            _limitOrder[tokenId_].executableAtTime = uint64(block.timestamp + minExecutabilityAge);
        }
    }

    /// @notice Deletes an announced order of the `account_` by an authorized module.
    /// @dev There is an event called `OrderCancelled` in the `OrderExecutionModule` that is emitted when an order is cancelled
    ///      by the user. This event is not emitted when the order is cancelled by an authorized module unless that module emits it.
    /// @param account_ The account that has an announced order.
    function deleteOrder(address account_) external onlyAuthorizedModule {
        delete _announcedOrder[account_];
    }

    /// @notice Deletes a limit order of the `tokenId_` by an authorized module.
    /// @param tokenId_ The ERC721 token ID of the position.
    function deleteLimitOrder(uint256 tokenId_) external onlyAuthorizedModule {
        _deleteLimitOrder(tokenId_);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Getter for the announced order of an account
    /// @param account_ The user account which has a pending order
    /// @return order_ The order struct
    function getAnnouncedOrder(address account_) external view returns (Order memory order_) {
        return _announcedOrder[account_];
    }

    /// @notice Getter for the announced limit order of a token ID
    /// @param tokenId_ The ERC721 token ID of the position
    /// @return order_ The order struct
    function getLimitOrder(uint256 tokenId_) external view returns (Order memory order_) {
        return _limitOrder[tokenId_];
    }

    /////////////////////////////////////////////
    //           Internal Functions            //
    /////////////////////////////////////////////

    /// @dev This function HAS to be called as soon as the transaction flow enters an announce function.
    function _prepareAnnouncementOrder(
        uint256 keeperFee_,
        address receiver_
    ) internal returns (uint64 executableAtTime_) {
        _preAnnouncementChores();

        if (receiver_ == address(0)) revert ICommonErrors.ZeroAddress("receiver");

        if (keeperFee_ < IKeeperFee(vault.moduleAddress(FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY)).getKeeperFee())
            revert ICommonErrors.InvalidFee(keeperFee_);

        // If the user has an existing pending order that expired, then cancel it.
        IOrderExecutionModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY)).cancelExistingOrder(
            receiver_
        );

        executableAtTime_ = uint64(block.timestamp + minExecutabilityAge);
    }

    function _preAnnouncementChores() internal {
        // Settle funding fees to not encounter the `MaxSkewReached` error.
        // This error could happen if the funding fees are not settled for a long time and the market is skewed long
        // for a long time.
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        vault.checkGlobalMarginPositive();
    }

    function _createLimitOrder(
        uint256 tokenId_,
        address positionOwner_,
        uint256 stopLossPrice_,
        uint256 profitTakePrice_
    ) private whenNotPaused {
        _preAnnouncementChores();

        uint64 executableAtTime_ = uint64(block.timestamp + minExecutabilityAge);

        if (stopLossPrice_ >= profitTakePrice_) revert InvalidLimitOrderPrices(stopLossPrice_, profitTakePrice_);

        _limitOrder[tokenId_] = Order({
            orderType: OrderType.LimitClose,
            orderData: abi.encode(AnnouncedLimitClose(tokenId_, stopLossPrice_, profitTakePrice_)),
            keeperFee: 0, // Not applicable for limit orders. Keeper fee will be determined at execution time.
            executableAtTime: executableAtTime_
        });

        emit LimitOrderAnnounced({
            account: positionOwner_,
            tokenId: tokenId_,
            stopLossPrice: stopLossPrice_,
            profitTakePrice: profitTakePrice_
        });
    }

    function _deleteLimitOrder(uint256 tokenId_) private {
        delete _limitOrder[tokenId_];

        emit LimitOrderCancelled({
            account: ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).ownerOf(tokenId_),
            tokenId: tokenId_
        });
    }

    function _setMinExecutabilityAge(uint64 minExecutabilityAge_) private {
        if (minExecutabilityAge_ == 0) revert ICommonErrors.ZeroValue("minExecutabilityAge");

        minExecutabilityAge = minExecutabilityAge_;
    }

    /////////////////////////////////////////////
    //          Owner Functions                //
    /////////////////////////////////////////////

    /// @notice Setter for the minimum time delayed executatibility time.
    /// @param minExecutabilityAge_ The minimum time that needs to expire between trade announcement and execution.
    function setMinExecutabilityAge(uint64 minExecutabilityAge_) external onlyOwner {
        _setMinExecutabilityAge(minExecutabilityAge_);
    }

    /// @notice Setter for the minimum deposit amount for stable LP collateral.
    /// @param minDepositAmountUSD_ The minimum deposit amount for stable LP collateral.
    function setminDepositAmountUSD(uint256 minDepositAmountUSD_) external onlyOwner {
        minDepositAmountUSD = minDepositAmountUSD_;
    }

    /// @notice Adds a caller to the whitelist.
    /// @dev Whitelisted callers can only call `announceXFor` functions.
    /// @param caller_ The address of the caller to add to the whitelist.
    function addAuthorizedCaller(address caller_) external onlyOwner {
        authorizedCallers[caller_] = true;
    }

    /// @notice Removes a caller from the whitelist.
    /// @param caller_ The address of the caller to remove from the whitelist.
    function removeAuthorizedCaller(address caller_) external onlyOwner {
        delete authorizedCallers[caller_];
    }
}
