// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {DecimalMath} from "../libraries/DecimalMath.sol";
import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";

import {ICommonErrors} from "../interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";
import {IControllerModule} from "../interfaces/IControllerModule.sol";
import {IOracleModule} from "../interfaces/IOracleModule.sol";
import "../interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "../interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

import {ModuleUpgradeable} from "./ModuleUpgradeable.sol";

/// @title ControllerBase
/// @notice Base controller module for new derivative markets.
/// @author dHEDGE
abstract contract ControllerBase is IControllerModule, ModuleUpgradeable {
    using SignedMath for int256;
    using DecimalMath for int256;
    using DecimalMath for uint256;
    using SafeCast for *;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event FundingFeesSettled(int256 settledFundingFee);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error InvalidMaxVelocitySkew(uint256 maxVelocitySkew);

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    /// @notice The last market skew recomputation timestamp.
    uint64 public lastRecomputedFundingTimestamp;

    /// @notice The last recomputed funding rate.
    /// @dev This includes 18 decimals and the funding rate is in %/day.
    int256 public lastRecomputedFundingRate;

    /// @notice Sum of funding rate over the entire lifetime of the market.
    int256 public cumulativeFundingRate;

    /// @notice The maximum funding velocity used to limit the funding rate fluctuations.
    /// @dev Funding velocity is used for calculating the current funding rate and acts as
    ///      a limit on how much the funding rate can change between funding re-computations.
    ///      The units are %/day (1e18 = 100% / day at max or min skew).
    uint256 public maxFundingVelocity;

    /// @notice The skew percentage at which the funding rate velocity is at its maximum.
    /// @dev When absolute pSkew > maxVelocitySkew, then funding velocity = maxFundingVelocity.
    ///      The units are in % (0.1e18 = 10% skew)
    uint256 public maxVelocitySkew;

    /// @notice The minimum funding rate to avoid highly negative funding rates during volatility.
    /// @dev It can be used to prevent the funding rate from going too low.
    ///      The limit is triggered when a transaction occurs (eg settle funding fees).
    ///      Units are in %/day (1e18 = 100% / day).
    int256 public minFundingRate;

    /// @notice Configuration of the 0-point or the targetted size to collateral ratio of the market.
    /// @dev Here collateral refers to the total LP balance.
    /// @dev Can be configured to have a market with target ratio for example 49/51 (longs/LPs).
    ///      For the target ratio of 49/51, the value should be 49e18/51
    ///      For the target ratio of 50/50, the value should be 1e18
    uint256 public targetSizeCollateralRatio;

    /////////////////////////////////////////////
    //                Functions                //
    /////////////////////////////////////////////

    /// @notice Initializes the Controller Module.
    /// @param maxFundingVelocity_ The maximum funding velocity used to limit the funding rate fluctuations.
    /// @param maxVelocitySkew_ The skew percentage at which the funding rate velocity is at its maximum.
    /// @param targetSizeCollateralRatio_ The offset for configuring the 0-point or the targetted size-collateral ratio of the market.
    /// @param minFundingRate_ The minimum funding rate to avoid highly negative funding rates during volatility.
    // solhint-disable-next-line func-name-mixedcase
    function __ControllerBase_init(
        IFlatcoinVault vault_,
        uint256 maxFundingVelocity_,
        uint256 maxVelocitySkew_,
        uint256 targetSizeCollateralRatio_,
        int256 minFundingRate_
    ) internal initializer {
        __Module_init(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY, IFlatcoinVault(vault_));

        maxFundingVelocity = maxFundingVelocity_;
        _setMaxVelocitySkew(maxVelocitySkew_);
        _setTargetSizeCollateralRatio(targetSizeCollateralRatio_);
        minFundingRate = minFundingRate_;

        if (minFundingRate_ > 0) {
            lastRecomputedFundingRate = minFundingRate_;
        }

        lastRecomputedFundingTimestamp = (block.timestamp).toUint64();
    }

    /// @notice Function to settle the funding fees between longs and LPs.
    /// @dev Anyone can call this function to settle the funding fees.
    ///      Note If the funding fees is negative, longs pay shorts and vice versa.
    function settleFundingFees() public virtual {
        int256 fundingRate = currentFundingRate();
        int256 unrecordedFundingRate = _unrecordedFunding(fundingRate);

        // Record the funding rate change and update the cumulative funding rate.
        cumulativeFundingRate += unrecordedFundingRate;

        // Calculate the funding fees accrued to the longs.
        // This will be used to adjust the global margin and collateral amounts.
        // This amount is in collateral asset terms.
        int256 fundingFees = _accruedFundingTotalByLongs(unrecordedFundingRate);

        // Update the latest funding rate and the latest funding recomputation timestamp.
        lastRecomputedFundingRate = fundingRate;
        lastRecomputedFundingTimestamp = (block.timestamp).toUint64();

        vault.updateGlobalMargin(fundingFees);
        vault.updateStableCollateralTotal(-fundingFees);

        emit FundingFeesSettled(fundingFees);
    }

    /////////////////////////////////////////////
    //           Funding Math Functions        //
    /////////////////////////////////////////////

    /// @dev Returns the pSkew = skew / skewScale capping the pSkew between [-1, 1].
    /// @return pSkew_ Returns the target skew adjusted proportional skew.
    function getProportionalSkew() public view virtual returns (int256 pSkew_) {
        uint256 sizeOpenedTotal = vault.getGlobalPositions().sizeOpenedTotal;
        uint256 stableCollateralTotal = vault.stableCollateralTotal();

        if (stableCollateralTotal > 0) {
            pSkew_ = int256(sizeOpenedTotal._divideDecimal(stableCollateralTotal)) - int256(targetSizeCollateralRatio);

            if (pSkew_ < -1e18 || pSkew_ > 1e18) {
                pSkew_ = DecimalMath.UNIT.min(pSkew_.max(-DecimalMath.UNIT));
            }
        } else {
            assert(sizeOpenedTotal == 0);
            pSkew_ = 0;
        }
    }

    /// @notice Returns the current skew of the market taking into account unaccrued funding.
    /// @dev Doesn't return targetCollateralSize ration adjusted skew.
    /// @return skew_ The current skew of the market.
    function getCurrentSkew() external view virtual returns (int256 skew_) {
        uint256 sizeOpenedTotal = vault.getGlobalPositions().sizeOpenedTotal;

        return
            int256(sizeOpenedTotal) -
            int256(vault.stableCollateralTotal()) -
            (int256(sizeOpenedTotal) * _unrecordedFunding(currentFundingRate())) /
            1e18;
    }

    /// @notice Function which returns the current funding rate (in %/day) based on the market conditions.
    /// @dev Includes 18 decimals and negative value indicates that the LPs pay the longs and vice versa.
    /// @return currentFundingRate_ The current funding rate.
    function currentFundingRate() public view virtual returns (int256 currentFundingRate_) {
        return _currentFundingRate(_fundingChangeSinceRecomputed());
    }

    /// @notice The funding velocity is based on the market skew and is scaled by the maxVelocitySkew.
    ///      With higher skews beyond the maxVelocitySkew, the velocity remains constant.
    function currentFundingVelocity() public view virtual returns (int256 currFundingVelocity_) {
        int256 proportionalSkew = getProportionalSkew();

        if (maxVelocitySkew > 0) {
            // Scale the funding velocity by the maxVelocitySkew and cap it at the maximum +- velocity.
            int256 fundingVelocity = (proportionalSkew * int256(maxFundingVelocity)) / int256(maxVelocitySkew);

            return int256(maxFundingVelocity).min(fundingVelocity.max(-int256(maxFundingVelocity)));
        }

        return proportionalSkew._multiplyDecimal(int256(maxFundingVelocity));
    }

    /// @dev The new entry in the funding sequence, appended when funding is recomputed.
    ///      It is the sum of the last entry and the unrecorded funding,
    ///      so the sequence accumulates running total over the market's lifetime.
    /// @return nextFundingEntry_ The next entry in the funding sequence.
    function nextFundingEntry() public view virtual returns (int256 nextFundingEntry_) {
        return cumulativeFundingRate + _unrecordedFunding(currentFundingRate());
    }

    /////////////////////////////////////////////
    //           Position Math Functions       //
    /////////////////////////////////////////////

    /// @notice Returns the PnL in terms of the collateral asset and not in dollars ($) by default.
    ///         This function rounds down the funding accrued to avoid rounding errors when subtracting individual funding fees accrued
    ///         from the global `marginDepositedTotal` value when closing the position.
    /// @param price_ The current price of the market asset.
    /// @return pnl_ The PnL in terms of the collateral asset.
    function profitLossTotal(uint256 price_) public view virtual returns (int256 pnl_) {
        FlatcoinVaultStructs.GlobalPositions memory globalPosition = vault.getGlobalPositions();
        int256 priceShift = int256(price_) - int256(globalPosition.averagePrice);

        return (int256(globalPosition.sizeOpenedTotal) * (priceShift)) / int256(price_);
    }

    /// @notice Calculates the funding fees accrued by a position.
    /// @dev To avoidd rounding errors when subtracting individual accrued funding fees from the global `marginDepositedTotal` value when closing the position,
    ///      we subtract 1 wei from the accrued funding fees in case the accrued funding fees is not 0.
    ///      This also means that there might be some amount left in the vault belonging to the longs which is not distributed.
    ///      This is insignificant and is a trade-off to avoid rounding errors.
    /// @param position_ The position to calculate the funding fees for.
    /// @return accruedFunding_ The funding fees accrued by the position in the collateral asset terms.
    function accruedFunding(
        LeverageModuleStructs.Position memory position_
    ) public view virtual returns (int256 accruedFunding_) {
        int256 net = _netFundingPerUnit(position_.entryCumulativeFunding);

        accruedFunding_ = int256(position_.additionalSize)._multiplyDecimal(net);

        return (accruedFunding_ != 0) ? accruedFunding_ - 1 : accruedFunding_;
    }

    /// @notice Calculates the funding fees accrued by the global position (all leverage traders).
    /// @return accruedFundingLongs_ The funding fees accrued by the global position (all leverage traders).
    function accruedFundingTotalByLongs() public view virtual returns (int256 accruedFundingLongs_) {
        return _accruedFundingTotalByLongs(_unrecordedFunding(currentFundingRate()));
    }

    /// @notice Returns the PnL in terms of the collateral asset and not in dollars ($) by default.
    ///      This function rounds down the PnL to avoid rounding errors when subtracting individual PnLs
    ///      from the global `marginDepositedTotal` value when closing the position.
    /// @param position_ The position to calculate the PnL for.
    /// @param price_ The current price of the market asset.
    /// @return pnl_ The PnL in terms of the collateral asset.
    function profitLoss(
        LeverageModuleStructs.Position memory position_,
        uint256 price_
    ) public view virtual returns (int256 pnl_) {
        int256 priceShift = int256(price_) - int256(position_.averagePrice);

        return (int256(position_.additionalSize) * (priceShift)) / int256(price_);
    }

    /// @notice Returns the total profit and loss of all the leverage positions.
    /// @dev Adjusts for the funding fees accrued.
    /// @param maxAge_ The maximum age of the oracle price to be used.
    /// @param priceDiffCheck_ A boolean to check if the price difference is within the threshold.
    /// @return fundingAdjustedPnL_ The total profit and loss of all the leverage positions.
    function fundingAdjustedLongPnLTotal(
        uint32 maxAge_,
        bool priceDiffCheck_
    ) public view virtual returns (int256 fundingAdjustedPnL_) {
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            asset: address(vault.collateral()),
            maxAge: maxAge_,
            priceDiffCheck: priceDiffCheck_
        });

        return profitLossTotal(currentPrice) + accruedFundingTotalByLongs();
    }

    /////////////////////////////////////////////
    //           Internal Functions            //
    /////////////////////////////////////////////

    /// @dev Function to calculate the unrecorded funding rate.
    /// @param currentFundingRate_ The current funding rate.
    /// @return unrecordedFunding_ The unrecorded funding rate.
    function _unrecordedFunding(int256 currentFundingRate_) internal view virtual returns (int256 unrecordedFunding_) {
        // If the current funding rate is equal to `minFundingRate`, then we first need to find the time when this happened.
        // That is, the inflection point at which the funding rate was first equal to `minFundingRate`.
        // Using this time, we can calculate the unrecorded funding rate.
        if (currentFundingRate_ != lastRecomputedFundingRate && currentFundingRate_ == minFundingRate) {
            int256 fundingVelocity = currentFundingVelocity();

            return
                ((minFundingRate - lastRecomputedFundingRate) * (minFundingRate + lastRecomputedFundingRate)) /
                (2 * fundingVelocity) +
                (
                    minFundingRate._multiplyDecimal(
                        (int256(_proportionalElapsedTime())) -
                            (minFundingRate - lastRecomputedFundingRate)._divideDecimal(fundingVelocity)
                    )
                );
        } else if (currentFundingRate_ * lastRecomputedFundingRate < 0) {
            // If the funding rate sign has flipped, we first need to find the time when the funding rate was first equal to 0.
            // That is, the inflection point at which the funding rate was first equal to 0.
            // Using this time, we can calculate the unrecorded funding rate.
            return
                ((currentFundingRate_ - lastRecomputedFundingRate) *
                    (currentFundingRate_ + lastRecomputedFundingRate)) / (2 * currentFundingVelocity());
        } else {
            return
                ((lastRecomputedFundingRate + currentFundingRate_) / 2)._multiplyDecimal(
                    int256(_proportionalElapsedTime())
                );
        }
    }

    /// @dev Function to calculate the funding rate based on market conditions.
    /// @param fundingChangeSinceRecomputed_ The change in funding rate since the last re-computation.
    /// @return currFundingRate_ The current funding rate.
    function _currentFundingRate(
        int256 fundingChangeSinceRecomputed_
    ) internal view virtual returns (int256 currFundingRate_) {
        int256 actualFundingRate = lastRecomputedFundingRate + fundingChangeSinceRecomputed_;

        if (actualFundingRate < minFundingRate) {
            return minFundingRate;
        }

        return actualFundingRate;
    }

    /// @dev Retrieves the change in funding rate since the last re-computation.
    ///      There is no variance in computation but will be affected based on outside modifications to
    ///      the market skew, max funding velocity, and the number of days passed since last computation.
    /// @return fundingChange_ The change in funding rate since the last re-computation.
    function _fundingChangeSinceRecomputed() internal view virtual returns (int256 fundingChange_) {
        int256 _currentFundingVelocity = currentFundingVelocity();

        if (lastRecomputedFundingRate <= minFundingRate && _currentFundingVelocity <= 0) {
            return 0;
        } else {
            return _currentFundingVelocity._multiplyDecimal(int256(_proportionalElapsedTime()));
        }
    }

    /// @dev Private function to calculate the total accrued funding by longs.
    /// @param unrecordedFunding_ The unrecorded funding rate.
    /// @return accruedFundingLongs_ The total accrued funding by longs in collateral asset terms
    function _accruedFundingTotalByLongs(
        int256 unrecordedFunding_
    ) internal view virtual returns (int256 accruedFundingLongs_) {
        int256 accruedFundingTotal = -int256(vault.getGlobalPositions().sizeOpenedTotal)._multiplyDecimal(
            unrecordedFunding_
        );

        return accruedFundingTotal;
    }

    /////////////////////////////////////////////
    //           Private Functions             //
    /////////////////////////////////////////////

    function _setMaxVelocitySkew(uint256 newMaxVelocitySkew_) private {
        if (newMaxVelocitySkew_ > 1e18 || newMaxVelocitySkew_ == 0) revert InvalidMaxVelocitySkew(newMaxVelocitySkew_);

        maxVelocitySkew = newMaxVelocitySkew_;
    }

    function _setTargetSizeCollateralRatio(uint256 targetSizeCollateralRatio_) private {
        if (targetSizeCollateralRatio_ == 0) {
            revert ICommonErrors.ZeroValue("targetSizeCollateralRatio");
        }

        targetSizeCollateralRatio = targetSizeCollateralRatio_;
    }

    /// @dev Calculates the current net funding per unit for a position.
    /// @param userFundingSequenceEntry_ The user's last funding sequence entry.
    /// @return netFundingPerUnit_ The net funding per unit for a position.
    function _netFundingPerUnit(int256 userFundingSequenceEntry_) private view returns (int256 netFundingPerUnit_) {
        return userFundingSequenceEntry_ - nextFundingEntry();
    }

    /// @dev Returns the time delta between the last funding timestamp and the current timestamp.
    /// @return elapsedTime_ The time delta between the last funding timestamp and the current timestamp.
    function _proportionalElapsedTime() private view returns (uint256 elapsedTime_) {
        return (block.timestamp - lastRecomputedFundingTimestamp)._divideDecimal(1 days);
    }

    /////////////////////////////////////////////
    //            Owner Functions              //
    /////////////////////////////////////////////

    /// @notice Setter for the maximum funding velocity.
    /// @param newMaxFundingVelocity_ The maximum funding velocity used to limit the funding rate fluctuations.
    /// @dev NOTE: `newMaxFundingVelocity_` should include 18 decimals.
    function setMaxFundingVelocity(uint256 newMaxFundingVelocity_) external onlyOwner {
        settleFundingFees(); // settle funding fees before updating the max funding velocity so that positions are not affected by the change
        maxFundingVelocity = newMaxFundingVelocity_;
    }

    /// @notice Setter for the maximum funding velocity skew.
    /// @param newMaxVelocitySkew_ The skew percentage at which the funding rate velocity is at its maximum.
    /// @dev NOTE: `newMaxVelocitySkew_` should include 18 decimals.
    function setMaxVelocitySkew(uint256 newMaxVelocitySkew_) external onlyOwner {
        settleFundingFees(); // settle funding fees before updating the max velocity skew so that positions are not affected by the change
        _setMaxVelocitySkew(newMaxVelocitySkew_);
    }

    /// @notice Setter for the target proportional skew.
    /// @dev In case you want the market to be 10% long skewed then this value should be 1.1e18.
    ///      If you want the market to be 10% short skewed then this value should be 0.9e18.
    /// @param targetSizeCollateralRatio_ The offset for configuring the 0-point or the targetted size-collateral ratio of the market.
    function setTargetSizeCollateralRatio(uint256 targetSizeCollateralRatio_) external onlyOwner {
        // Since modifying the target skew offset can affect the funding rate, we need to settle the funding fees first.
        settleFundingFees();
        _setTargetSizeCollateralRatio(targetSizeCollateralRatio_);
    }

    /// @notice Setter for the minimum funding rate.
    /// @param newMinFundingRate_ The minimum funding rate to avoid highly negative funding rates during volatility.
    function setMinFundingRate(int256 newMinFundingRate_) public onlyOwner {
        settleFundingFees(); // settle funding fees before update to ensure calculations are correct

        // If one creates a chart to visualize the funding rate up until when `newMinFundingRate_` is set, it will look like a step function (a sudden jump/fall).
        // The inflection point can't be calculated as the funding rate is not continuous.
        // An example where this is a problem is when the initial `minFundingRate` is 0 and the new `minFundingRate` is +ve.
        // If the new `minFundingRate` is set when the market is delta neutral or when the market is not funded, the funding velocity will be 0
        // which will cause the `_unrecordedFunding` to revert.
        // The following is ok to do as long as `lastRecomputedFundingTimestamp` is updated to the current timestamp.
        // This is done when this function calls `settleFundingFees`.
        if (currentFundingRate() < newMinFundingRate_) {
            lastRecomputedFundingRate = newMinFundingRate_;
        }

        minFundingRate = newMinFundingRate_;
    }

    uint256[43] private __gap;
}
