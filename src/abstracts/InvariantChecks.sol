// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";
import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";
import {IStableModule} from "../interfaces/IStableModule.sol";
import {ILeverageModule} from "../interfaces/ILeverageModule.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";

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
