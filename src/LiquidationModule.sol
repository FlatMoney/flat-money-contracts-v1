// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {OracleModifiers} from "./abstracts/OracleModifiers.sol";
import {FlatcoinErrors} from "./libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "./libraries/FlatcoinStructs.sol";
import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {FlatcoinEvents} from "./libraries/FlatcoinEvents.sol";
import {PerpMath} from "./libraries/PerpMath.sol";
import {InvariantChecks} from "./misc/InvariantChecks.sol";

import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";
import {ILimitOrder} from "./interfaces/ILimitOrder.sol";

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
