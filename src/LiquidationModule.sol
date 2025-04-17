// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {OracleModifiers} from "./abstracts/OracleModifiers.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {DecimalMath} from "./libraries/DecimalMath.sol";
import {InvariantChecks} from "./abstracts/InvariantChecks.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {IControllerModule} from "./interfaces/IControllerModule.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";

import "./interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

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
    using DecimalMath for int256;
    using DecimalMath for uint256;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event LiquidationFeeRatioModified(uint256 oldRatio, uint256 newRatio);
    event LiquidationBufferRatioModified(uint256 oldRatio, uint256 newRatio);
    event LiquidationFeeBoundsModified(uint256 oldMin, uint256 oldMax, uint256 newMin, uint256 newMax);
    event PositionLiquidated(
        uint256 tokenId,
        address liquidator,
        uint256 liquidationFee,
        uint256 closePrice,
        LeverageModuleStructs.PositionSummary positionSummary
    );

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error CannotLiquidate(uint256 tokenId);
    error InvalidBounds(uint256 lower, uint256 upper);

    /////////////////////////////////////////////
    //                State                    //
    /////////////////////////////////////////////

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

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IFlatcoinVault vault_,
        uint128 liquidationFeeRatio_,
        uint128 liquidationBufferRatio_,
        uint256 liquidationFeeLowerBound_,
        uint256 liquidationFeeUpperBound_
    ) external initializer {
        __Module_init(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY, vault_);
        __ReentrancyGuard_init();

        _setLiquidationFeeRatio(liquidationFeeRatio_);
        _setLiquidationBufferRatio(liquidationBufferRatio_);
        _setLiquidationFeeBounds(liquidationFeeLowerBound_, liquidationFeeUpperBound_);
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    /// @notice Function to liquidate a position after Pyth price update.
    /// @dev WARNING: Kept here for backwards compatibility, will be deprecated soon.
    /// @param tokenID_ The token ID of the leverage position.
    /// @param priceUpdateData_ The price update data to be used for updating the Pyth price.
    function liquidate(
        uint256 tokenID_,
        bytes[] calldata priceUpdateData_
    ) external payable updatePythPrice(vault, msg.sender, priceUpdateData_) {
        liquidate(tokenID_);
    }

    /// @notice Function to liquidate a position without Pyth price update.
    /// @dev WARNING: Kept here for backwards compatibility, will be deprecated soon.
    /// @param tokenID_ The token ID of the leverage position.
    function liquidate(uint256 tokenID_) public {
        uint256[] memory tokenIdArr = new uint256[](1);
        tokenIdArr[0] = tokenID_;

        tokenIdArr = liquidate(tokenIdArr);

        if (tokenIdArr.length != 1) revert CannotLiquidate(tokenID_);
    }

    /// @notice Function to liquidate multiple positions after Pyth price update.
    /// @param tokenID_ The token ID of the leverage position.
    /// @param priceUpdateData_ The price update data to be used for updating the Pyth price.
    /// @return liquidatedIds_ The token IDs of the liquidated positions.
    function liquidate(
        uint256[] calldata tokenID_,
        bytes[] calldata priceUpdateData_
    ) external payable updatePythPrice(vault, msg.sender, priceUpdateData_) returns (uint256[] memory liquidatedIds_) {
        return liquidate(tokenID_);
    }

    /// @notice Function to liquidate multiple positions without Pyth price update.
    /// @param tokenID_ The token ID of the leverage position.
    /// @return liquidatedIds_ The token IDs of the liquidated positions.
    function liquidate(
        uint256[] memory tokenID_
    ) public nonReentrant whenNotPaused returns (uint256[] memory liquidatedIds_) {
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            asset: address(vault.collateral()),
            maxAge: 86_400,
            priceDiffCheck: true
        });

        // Settle funding fees accrued till now.
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        liquidatedIds_ = new uint256[](tokenID_.length);
        uint256 counter;

        for (uint256 i; i < tokenID_.length; ++i) {
            if (canLiquidate(tokenID_[i], currentPrice)) {
                _processLiquidation(tokenID_[i], currentPrice);

                liquidatedIds_[counter] = tokenID_[i];
                ++counter;
            }
        }

        uint256 reduceLength = tokenID_.length - counter;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(liquidatedIds_, sub(mload(liquidatedIds_), reduceLength))
        }
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Function which determines if a leverage position can be liquidated or not.
    /// @param tokenId_ The token ID of the leverage position.
    /// @return liquidatable_ True if the position can be liquidated, false otherwise.
    function canLiquidate(uint256 tokenId_) public view returns (bool liquidatable_) {
        // Get the current price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        return canLiquidate(tokenId_, currentPrice);
    }

    /// @param tokenId_ The token ID of the leverage position.
    /// @param price_ The current price of the collateral asset.
    function canLiquidate(uint256 tokenId_, uint256 price_) public view returns (bool liquidatable_) {
        LeverageModuleStructs.Position memory position = vault.getPosition(tokenId_);

        // No liquidations of empty positions.
        if (position.additionalSize == 0) {
            return false;
        }

        LeverageModuleStructs.PositionSummary memory positionSummary = ILeverageModule(
            vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)
        ).getPositionSummary(position, price_);

        uint256 lMargin = getLiquidationMargin(position.additionalSize, price_);

        return positionSummary.marginAfterSettlement <= int256(lMargin);
    }

    /// @notice Function to calculate the liquidation fee awarded for a liquidating a given position.
    /// @param tokenId_ The token ID of the leverage position.
    /// @return liquidationFee_ The liquidation fee in collateral units.
    function getLiquidationFee(uint256 tokenId_) public view returns (uint256 liquidationFee_) {
        // Get the latest price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        return getLiquidationFee(vault.getPosition(tokenId_).additionalSize, currentPrice);
    }

    /// @notice Function to calculate the liquidation margin for a given additional size amount.
    /// @param additionalSize_ The additional size amount for which the liquidation margin is to be calculated.
    /// @return liquidationMargin_ The liquidation margin in collateral units.
    function getLiquidationMargin(uint256 additionalSize_) public view returns (uint256 liquidationMargin_) {
        // Get the latest price from the oracle module.
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        return getLiquidationMargin(additionalSize_, currentPrice);
    }

    /// @notice The minimal margin at which liquidation can happen.
    ///      Is the sum of liquidationBuffer, liquidationFee (for flagger) and keeperLiquidationFee (for liquidator)
    ///      The liquidation margin contains a buffer that is proportional to the position
    ///      size. The buffer should prevent liquidation happening at negative margin (due to next price being worse).
    /// @param positionSize_ size of position in fixed point decimal collateral asset units.
    /// @param currentPrice_ current price of the collateral asset in USD units.
    /// @return lMargin_ liquidation margin to maintain in collateral asset units.
    function getLiquidationMargin(uint256 positionSize_, uint256 currentPrice_) public view returns (uint256 lMargin_) {
        uint256 liquidationBuffer = positionSize_._multiplyDecimal(liquidationBufferRatio);

        // The liquidation margin consists of the liquidation buffer, liquidation fee and the keeper fee for covering execution costs.
        return liquidationBuffer + getLiquidationFee(positionSize_, currentPrice_);
    }

    /// The fee charged from the margin during liquidation. Fee is proportional to position size.
    /// @dev There is a cap on the fee to prevent liquidators from being overpayed.
    /// @param positionSize_ size of position in fixed point decimal baseAsset units.
    /// @param currentPrice_ current price of the collateral asset in USD units.
    /// @return liqFee_ liquidation fee to be paid to liquidator in collateral asset units.
    function getLiquidationFee(uint256 positionSize_, uint256 currentPrice_) public view returns (uint256 liqFee_) {
        uint8 collateralDecimals = vault.collateral().decimals();

        // size(collateral decimals) * price(18 decimals) * fee-ratio(18 decimals) * 1e18 / (10^(collateral decimals)) => proportionalFee(18 decimals)
        uint256 proportionalFee = positionSize_
            ._multiplyDecimal(liquidationFeeRatio)
            ._multiplyDecimal(currentPrice_)
            ._divideDecimal(10 ** (collateralDecimals));

        uint256 cappedProportionalFee = proportionalFee > liquidationFeeUpperBound
            ? liquidationFeeUpperBound
            : proportionalFee;

        uint256 lFeeUSD = cappedProportionalFee < liquidationFeeLowerBound
            ? liquidationFeeLowerBound
            : cappedProportionalFee;

        // Return liquidation fee in collateral asset units.
        return (lFeeUSD * (10 ** collateralDecimals)) / currentPrice_;
    }

    /////////////////////////////////////////////
    //        Internal/Private Functions       //
    /////////////////////////////////////////////

    function _setLiquidationFeeRatio(uint128 newLiquidationFeeRatio_) private {
        if (newLiquidationFeeRatio_ == 0) revert ICommonErrors.ZeroValue("newLiquidationFeeRatio");

        emit LiquidationFeeRatioModified(liquidationFeeRatio, newLiquidationFeeRatio_);

        liquidationFeeRatio = newLiquidationFeeRatio_;
    }

    function _setLiquidationBufferRatio(uint128 newLiquidationBufferRatio_) private {
        if (newLiquidationBufferRatio_ == 0) revert ICommonErrors.ZeroValue("newLiquidationBufferRatio");

        emit LiquidationBufferRatioModified(liquidationBufferRatio, newLiquidationBufferRatio_);

        liquidationBufferRatio = newLiquidationBufferRatio_;
    }

    function _setLiquidationFeeBounds(
        uint256 newLiquidationFeeLowerBound_,
        uint256 newLiquidationFeeUpperBound_
    ) private {
        if (newLiquidationFeeUpperBound_ == 0 || newLiquidationFeeLowerBound_ == 0)
            revert ICommonErrors.ZeroValue("newLiquidationFee");
        if (newLiquidationFeeUpperBound_ < newLiquidationFeeLowerBound_)
            revert InvalidBounds(newLiquidationFeeLowerBound_, newLiquidationFeeUpperBound_);

        emit LiquidationFeeBoundsModified(
            liquidationFeeLowerBound,
            liquidationFeeUpperBound,
            newLiquidationFeeLowerBound_,
            newLiquidationFeeUpperBound_
        );

        liquidationFeeLowerBound = newLiquidationFeeLowerBound_;
        liquidationFeeUpperBound = newLiquidationFeeUpperBound_;
    }

    /// @dev WARNING: This function DOESN'T check if the position is liquidatable.
    ///      That check has to be done before calling this function.
    function _processLiquidation(
        uint256 tokenId_,
        uint256 currentPrice_
    ) private liquidationInvariantChecks(vault, tokenId_) {
        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));
        LeverageModuleStructs.Position memory position = vault.getPosition(tokenId_);
        LeverageModuleStructs.PositionSummary memory positionSummary = leverageModule.getPositionSummary(
            position,
            currentPrice_
        );

        // Check that the total margin deposited by the long traders is not -ve.
        // To get this amount, we will have to account for the PnL and funding fees accrued.
        int256 settledMargin = positionSummary.marginAfterSettlement;
        uint256 liquidatorFee;

        // If the settled margin is greater than 0, send a portion (or all) of the margin to the liquidator and LPs.
        if (settledMargin > 0) {
            // Calculate the liquidation fees to be sent to the caller.
            uint256 expectedLiquidationFee = getLiquidationFee(position.additionalSize, currentPrice_);

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
        vault.deletePosition(tokenId_);

        // If the position token is locked because of an announced order, it should still be liquidatable
        leverageModule.burn(tokenId_);

        emit PositionLiquidated(tokenId_, msg.sender, liquidatorFee, currentPrice_, positionSummary);
    }

    /////////////////////////////////////////////
    //            Owner Functions              //
    /////////////////////////////////////////////

    function setLiquidationFeeRatio(uint128 newLiquidationFeeRatio_) external onlyOwner {
        _setLiquidationFeeRatio(newLiquidationFeeRatio_);
    }

    function setLiquidationBufferRatio(uint128 newLiquidationBufferRatio_) external onlyOwner {
        _setLiquidationBufferRatio(newLiquidationBufferRatio_);
    }

    function setLiquidationFeeBounds(
        uint256 newLiquidationFeeLowerBound_,
        uint256 newLiquidationFeeUpperBound_
    ) external onlyOwner {
        _setLiquidationFeeBounds(newLiquidationFeeLowerBound_, newLiquidationFeeUpperBound_);
    }
}
