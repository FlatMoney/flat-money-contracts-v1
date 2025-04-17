// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";

import {FeeManager} from "./abstracts/FeeManager.sol";

import "./interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "./interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

/// @title FlatcoinVault
/// @author dHEDGE
/// @notice Contains state to be reused by different modules of the system.
/// @dev Holds the stable LP deposits and leverage traders' collateral amounts.
///      Also stores other related contract address pointers.
contract FlatcoinVault is IFlatcoinVault, OwnableUpgradeable, FeeManager {
    using SafeCast for *;
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.UintSet;

    /////////////////////////////////////////////
    //                  Errors                 //
    /////////////////////////////////////////////

    error MaxPositionsInitZero();
    error MarginMismatchOnClose();
    error InsufficientGlobalMargin();
    error AddressNotWhitelisted(address account);
    error DepositCapReached(uint256 collateralCap);

    /////////////////////////////////////////////
    //                  State                  //
    /////////////////////////////////////////////

    /// @notice The collateral token address.
    IERC20Metadata public collateral;

    /// @notice Total collateral deposited by users minting the flatcoin.
    /// @dev This value is adjusted due to funding fee payments.
    uint256 public stableCollateralTotal;

    /// @notice Maximum cap on the total stable LP deposits.
    uint256 public stableCollateralCap;

    /// @notice The maximum limit of total leverage long size vs stable LP.
    /// @dev This prevents excessive short skew of stable LPs by capping long trader total open interest.
    ///      Care needs to be taken when increasing this value as it can lead to the stable LPs being excessively short.
    uint256 public skewFractionMax;

    /// @notice The max absolute error value allowed for invariant calculations.
    /// @dev Primarily used by checks in the `InvariantChecks.sol`.
    /// @dev Has to be configured as per the collateral token decimals.
    /// @dev Example, for 18 decimal tokens, we can consider this value to be 1e6.
    uint256 public maxDeltaError;

    ///  @notice The maximum positions and whitelist below are used for non-linear positions payoffs (eg. Options market)
    //           because it's not possible to aggregate the total PnL of all the positions in the system.
    //           Therefore a limit of (eg. 3 positions) is set to prevent the transactions from consuming too much gas.
    /// @dev The maximum number of open positions. 0 = no cap on the number of open positions
    uint256 public maxPositions;

    /// @dev Set of tracked open positions when maxPositions > 0
    EnumerableSet.UintSet internal _maxPositionsSet;

    /// @dev Adresses that are able to open positions
    mapping(address positionOpenWhitelist => bool whitelisted) internal _maxPositionsWhitelist;

    /// @notice Holds mapping between module keys and module addresses.
    ///         A module key is a keccak256 hash of the module name.
    /// @dev Make sure that a module key is created using the following format:
    ///      moduleKey = bytes32(<MODULE_NAME>)
    ///      All the module keys should reside in a single file (see FlatcoinModuleKeys.sol).
    mapping(bytes32 moduleKey => address moduleAddress) public moduleAddress;

    /// @notice Holds mapping between module addresses and their authorization status.
    mapping(address moduleAddress => bool authorized) public isAuthorizedModule;

    /// @notice Holds mapping between module keys and their pause status.
    mapping(bytes32 moduleKey => bool paused) public isModulePaused;

    /// @dev Tracks global totals of leverage trade positions to be able to:
    ///      - price stable LP value.
    ///      - calculate the funding rate.
    ///      - calculate the skew.
    ///      - calculate funding fees payments.
    FlatcoinVaultStructs.GlobalPositions internal _globalPositions;

    /// @dev Holds mapping between user addresses and their leverage positions.
    mapping(uint256 tokenId => LeverageModuleStructs.Position userPosition) internal _positions;

    /////////////////////////////////////////////
    //                Modifiers                //
    /////////////////////////////////////////////

    modifier onlyAuthorizedModule() {
        if (isAuthorizedModule[msg.sender] == false) revert ICommonErrors.OnlyAuthorizedModule(msg.sender);
        _;
    }

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
    /// @param collateral_ The collateral token address.
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient.
    /// @param protocolFeePercentage_ The protocol fee percentage.
    /// @param leverageTradingFee_ The leverage trading fee.
    /// @param stableWithdrawFee_ The stable LP withdrawal fee.
    /// @param maxDeltaError_ The max absolute error value allowed for invariant calculations.
    /// @param skewFractionMax_ The maximum limit of total leverage long size vs stable LP.
    /// @param stableCollateralCap_ The maximum cap on the total stable LP deposits.
    /// @param maxPositions_ The maximum number of open positions. Setting to 0 bypasses the max positions check.
    function initialize(
        IERC20Metadata collateral_,
        address protocolFeeRecipient_,
        uint64 protocolFeePercentage_,
        uint64 leverageTradingFee_,
        uint64 stableWithdrawFee_,
        uint256 maxDeltaError_,
        uint256 skewFractionMax_,
        uint256 stableCollateralCap_,
        uint256 maxPositions_
    ) external initializer {
        __Ownable_init(msg.sender);
        __FeeManager_init(protocolFeeRecipient_, protocolFeePercentage_, leverageTradingFee_, stableWithdrawFee_);

        collateral = collateral_;
        stableCollateralCap = stableCollateralCap_;
        skewFractionMax = skewFractionMax_;
        maxDeltaError = maxDeltaError_;
        maxPositions = maxPositions_;
    }

    /////////////////////////////////////////////
    //            Module Functions             //
    /////////////////////////////////////////////

    /// @notice Collateral can only be withdrawn by the flatcoin contracts (Delayed Orders, Stable or Leverage module).
    function sendCollateral(address to_, uint256 amount_) external onlyAuthorizedModule {
        collateral.safeTransfer(to_, amount_);
    }

    /// @notice Function to set the position of a leverage trader.
    /// @dev This function is only callable by the authorized modules.
    /// @param newPosition_ The new struct encoded position of the leverage trader.
    /// @param tokenId_ The token ID of the leverage trader.
    function setPosition(
        LeverageModuleStructs.Position calldata newPosition_,
        uint256 tokenId_
    ) external onlyAuthorizedModule {
        if (maxPositions > 0) {
            if (_maxPositionsSet.length() >= maxPositions) revert ICommonErrors.MaxPositionsReached();

            _maxPositionsSet.add(tokenId_);
        }

        _positions[tokenId_] = newPosition_;
    }

    /// @notice Function to delete the position of a leverage trader.
    /// @dev This function is only callable by the authorized modules.
    /// @param tokenId_ The token ID of the leverage trader.
    function deletePosition(uint256 tokenId_) external onlyAuthorizedModule {
        if (maxPositions > 0) _maxPositionsSet.remove(tokenId_);

        delete _positions[tokenId_];
    }

    /// @notice Function to update the stable collateral total.
    /// @dev This function is only callable by the authorized modules.
    ///      When stableCollateralAdjustment_ is negative, it means that the stable collateral total is decreasing.
    /// @param stableCollateralAdjustment_ The adjustment to the stable collateral total.
    function updateStableCollateralTotal(int256 stableCollateralAdjustment_) external onlyAuthorizedModule {
        _updateStableCollateralTotal(stableCollateralAdjustment_);
    }

    /// @notice Function to update the global margin by authorized modules.
    /// @param marginDelta_ The change in the margin deposited total.
    function updateGlobalMargin(int256 marginDelta_) external onlyAuthorizedModule {
        // In the worst case scenario that the last position which remained open is underwater,
        // We set the margin deposited total to negative. Once the underwater position is liquidated,
        // then the funding fees will be reverted and the total will be positive again.
        _globalPositions.marginDepositedTotal += marginDelta_;
    }

    /// @notice Function to update the global position data.
    /// @dev This function is only callable by the authorized modules.
    /// @param price_ The current price of the underlying asset.
    /// @param marginDelta_ The change in the margin deposited total.
    /// @param additionalSizeDelta_ The change in the size opened total.
    function updateGlobalPositionData(
        uint256 price_,
        int256 marginDelta_,
        int256 additionalSizeDelta_
    ) external onlyAuthorizedModule {
        // Note that technically, even the funding fees should be accounted for when computing the margin deposited total.
        // However, since the funding fees are settled at the same time as the global position data is updated,
        // we can ignore the funding fees here.
        int256 newMarginDepositedTotal = _globalPositions.marginDepositedTotal + marginDelta_;

        int256 averageEntryPrice = int256(_globalPositions.averagePrice);
        int256 sizeOpenedTotal = int256(_globalPositions.sizeOpenedTotal);

        // Recompute the average entry price.
        if ((sizeOpenedTotal + additionalSizeDelta_) != 0) {
            int256 newAverageEntryPrice = ((averageEntryPrice * sizeOpenedTotal) +
                (int256(price_) * additionalSizeDelta_)) / (sizeOpenedTotal + additionalSizeDelta_);

            _globalPositions = FlatcoinVaultStructs.GlobalPositions({
                marginDepositedTotal: newMarginDepositedTotal,
                sizeOpenedTotal: (int256(_globalPositions.sizeOpenedTotal) + additionalSizeDelta_).toUint256(),
                averagePrice: uint256(newAverageEntryPrice)
            });
        } else {
            // Add the remaining margin to the stable collateral total.
            // This is to avoid 'InvariantViolation("collateralNet1")' in the InvariantChecks contract.
            if (newMarginDepositedTotal > 0) {
                stableCollateralTotal += uint256(newMarginDepositedTotal);
            } else {
                stableCollateralTotal -= uint256(-newMarginDepositedTotal);
            }

            delete _globalPositions;
        }
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Function to check if the account is whitelisted to open positions when maxPositions > 0.
    function isPositionOpenWhitelisted(address account_) public view returns (bool whitelisted_) {
        return _maxPositionsWhitelist[account_];
    }

    /// @notice Function to check if the max positions are reached when maxPositions > 0.
    function isMaxPositionsReached() public view returns (bool maxReached_) {
        return maxPositions > 0 && _maxPositionsSet.length() >= maxPositions;
    }

    /// @notice Returns the position token IDs only if maxPositions > 0.
    /// @dev Used for non-linear positions payoffs (eg. Options market) where we have to limit the number of open positions.
    function getMaxPositionIds() external view returns (uint256[] memory openPositionIds_) {
        return _maxPositionsSet.values();
    }

    /// @notice Function to get the position details of associated with a `tokenId_`.
    /// @dev This can be used by modules to get the position details of a leverage trader.
    /// @param tokenId_ The token ID of the leverage trader.
    /// @return positionDetails_ The position struct with details.
    function getPosition(
        uint256 tokenId_
    ) external view returns (LeverageModuleStructs.Position memory positionDetails_) {
        return _positions[tokenId_];
    }

    /// @notice Function to get the global position details.
    /// @dev This can be used by modules to get the global position details.
    /// @return globalPositionsDetails_ The global position struct with details.
    function getGlobalPositions()
        external
        view
        returns (FlatcoinVaultStructs.GlobalPositions memory globalPositionsDetails_)
    {
        return _globalPositions;
    }

    /// @notice Asserts that the system will not be too skewed towards longs after additional skew is added (position change).
    /// @param sizeChange_ The proposed change in additional size
    /// @param stableCollateralChange_ The proposed change in the stable collateral
    function checkSkewMax(uint256 sizeChange_, int256 stableCollateralChange_) public view {
        // check that skew is not essentially disabled
        if (skewFractionMax < type(uint256).max) {
            uint256 sizeOpenedTotal = _globalPositions.sizeOpenedTotal;

            if (stableCollateralTotal == 0) revert ICommonErrors.ZeroValue("stableCollateralTotal");
            assert(int256(stableCollateralTotal) + stableCollateralChange_ >= 0);

            // if the longs are closed completely then there is no reason to check if long skew has reached max
            if (sizeOpenedTotal + sizeChange_ == 0) return;

            uint256 longSkewFraction = (int256((sizeOpenedTotal + sizeChange_) * 1e18) /
                (int256(stableCollateralTotal) + stableCollateralChange_)).toUint256();

            if (longSkewFraction > skewFractionMax) revert ICommonErrors.MaxSkewReached(longSkewFraction);
        }
    }

    /// @notice Reverts if the stable LP deposit cap is reached on deposit.
    /// @param depositAmount_ The amount of stable LP tokens to deposit.
    function checkCollateralCap(uint256 depositAmount_) public view {
        uint256 collateralCap = stableCollateralCap;

        if (stableCollateralTotal + depositAmount_ > collateralCap) revert DepositCapReached(collateralCap);
    }

    /// @notice Function to check if global margin is positive or not.
    ///         If it isn't positive, then there are positions which are underwater.
    function checkGlobalMarginPositive() public view {
        int256 globalMarginDepositedTotal = _globalPositions.marginDepositedTotal;

        if (globalMarginDepositedTotal < 0) revert InsufficientGlobalMargin();
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Setter for the maximum leverage total skew fraction.
    /// @dev This ensures that stable LPs are not too short by capping long trader total open interest.
    ///      Note that `skewFractionMax_` should include 18 decimals.
    /// @param skewFractionMax_ The maximum limit of total leverage long size vs stable LP.
    function setSkewFractionMax(uint256 skewFractionMax_) external onlyOwner {
        skewFractionMax = skewFractionMax_;
    }

    /// @notice Function to add multiple authorized modules.
    /// @dev NOTE: This function can overwrite an existing authorized module.
    /// @param modules_ The array of authorized modules to add.
    function addAuthorizedModules(FlatcoinVaultStructs.AuthorizedModule[] calldata modules_) external onlyOwner {
        uint8 modulesLength = uint8(modules_.length);

        for (uint8 i; i < modulesLength; ++i) {
            addAuthorizedModule(modules_[i]);
        }
    }

    /// @notice Function to remove an authorized module.
    /// @param modKey_ The module key of the module to remove.
    function removeAuthorizedModule(bytes32 modKey_) external onlyOwner {
        address modAddress = moduleAddress[modKey_];

        delete moduleAddress[modKey_];
        delete isAuthorizedModule[modAddress];
    }

    /// @notice Function to pause the module
    /// @param moduleKey_ The module key of the module to pause.
    function pauseModule(bytes32 moduleKey_) external onlyOwner {
        isModulePaused[moduleKey_] = true;
    }

    /// @notice Function to unpause the critical functions
    /// @param moduleKey_ The module key of the module to unpause.
    function unpauseModule(bytes32 moduleKey_) external onlyOwner {
        isModulePaused[moduleKey_] = false;
    }

    /// @notice Setter for the stable collateral cap.
    /// @param collateralCap_ The maximum cap on the total stable LP deposits.
    function setStableCollateralCap(uint256 collateralCap_) external onlyOwner {
        stableCollateralCap = collateralCap_;
    }

    /// @notice Function to set an authorized module.
    /// @dev NOTE: This function can overwrite an existing authorized module.
    /// @param module_ The authorized module to add.
    function addAuthorizedModule(FlatcoinVaultStructs.AuthorizedModule calldata module_) public onlyOwner {
        if (module_.moduleAddress == address(0)) revert ICommonErrors.ZeroAddress("moduleAddress");
        if (module_.moduleKey == bytes32(0)) revert ICommonErrors.ZeroValue("moduleKey");

        moduleAddress[module_.moduleKey] = module_.moduleAddress;
        isAuthorizedModule[module_.moduleAddress] = true;
    }

    /// @notice Setter for the max absolute error value allowed for invariant calculations.
    /// @param maxDeltaError_ The new max absolute error value allowed for invariant calculations.
    function setMaxDeltaError(uint256 maxDeltaError_) external onlyOwner {
        maxDeltaError = maxDeltaError_;
    }

    /// @notice Function to set the maximum number of open positions.
    /// @dev This should be set at initialisation and not settable from 0 after deployment.
    function setMaxPositions(uint256 maxPositions_) external onlyOwner {
        if (maxPositions_ == 0) revert ICommonErrors.ZeroValue("maxPositions_");
        if (maxPositions == 0 && stableCollateralTotal > 0) revert MaxPositionsInitZero(); // cannot create max positions if it was set to 0 initially and positions opened already
        if (_maxPositionsSet.length() > maxPositions_) revert ICommonErrors.MaxPositionsReached(); // need to burn existing position(s) to decrease max positions

        maxPositions = maxPositions_;
    }

    /// @notice Function to set the positions open whitelist when a maximum is set.
    /// @dev Only works if the maxPositions is set to > 0 during market initialisation.
    function setMaxPositionsWhitelist(address account_, bool whitelisted_) external onlyOwner {
        _maxPositionsWhitelist[account_] = whitelisted_;
    }

    /////////////////////////////////////////////
    //             Private Functions           //
    /////////////////////////////////////////////
    function _updateStableCollateralTotal(int256 stableCollateralAdjustment_) private {
        int256 newStableCollateralTotal = int256(stableCollateralTotal) + stableCollateralAdjustment_;

        // The stable collateral shouldn't be negative as the other calculations which depend on this
        // will behave in unexpected manners.
        if (newStableCollateralTotal < 0) revert ICommonErrors.ValueNotPositive("stableCollateralTotal");

        stableCollateralTotal = newStableCollateralTotal.toUint256();
    }
}
