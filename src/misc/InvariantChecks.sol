// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {FlatcoinErrors} from "../libraries/FlatcoinErrors.sol";
import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";
import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";
import {IStableModule} from "../interfaces/IStableModule.sol";
import {ILeverageModule} from "../interfaces/ILeverageModule.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";

/// @title InvariantChecks
/// @author dHEDGE
/// @notice Contract module for critical invariant checking on the protocol.
abstract contract InvariantChecks {
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

    /// @notice Invariant checks on order execution
    /// @dev Checks:
    ///      1. Collateral net: The vault collateral balance relative to tracked collateral on both stable LP and leverage side should not change
    ///      2. Stable collateral per share: Stable LP value per share should never decrease after order execution. It should only increase due to collected trading fees
    modifier orderInvariantChecks(IFlatcoinVault vault) {
        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantOrder memory invariantBefore = InvariantOrder({ // helps with stack too deep
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        _;

        InvariantOrder memory invariantAfter = InvariantOrder({
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare()
        });

        _collateralNetBalanceRemainsUnchanged(invariantBefore.collateralNet, invariantAfter.collateralNet);
        _stableCollateralPerShareIncreasesOrRemainsUnchanged(
            stableModule.totalSupply(),
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );
        _globalAveragePriceIsNotNegative(vault);
    }

    /// @notice Invariant checks on order liquidation
    /// @dev For liquidations, stableCollateralPerShare can decrease if the position is underwater.
    modifier liquidationInvariantChecks(IFlatcoinVault vault, uint256 tokenId) {
        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));

        InvariantLiquidation memory invariantBefore = InvariantLiquidation({ // helps with stack too deep
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY))
                .getPositionSummary(tokenId)
                .marginAfterSettlement,
            liquidationFee: ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY))
                .getLiquidationFee(tokenId)
        });

        _;

        InvariantLiquidation memory invariantAfter = InvariantLiquidation({
            collateralNet: _getCollateralNet(vault),
            stableCollateralPerShare: stableModule.stableCollateralPerShare(),
            remainingMargin: 0, // not used
            liquidationFee: 0 // not used
        });

        _stableCollateralPerShareLiquidation(
            stableModule,
            invariantBefore.liquidationFee,
            invariantBefore.remainingMargin,
            invariantBefore.stableCollateralPerShare,
            invariantAfter.stableCollateralPerShare
        );

        _collateralNetBalanceRemainsUnchanged(invariantBefore.collateralNet, invariantAfter.collateralNet);
        _globalAveragePriceIsNotNegative(vault);
    }

    /// @dev Returns the difference between actual total collateral balance in the vault vs tracked collateral
    ///      Tracked collateral should be updated when depositing to stable LP (stableCollateralTotal) or
    ///      opening leveraged positions (marginDepositedTotal).
    function _getCollateralNet(IFlatcoinVault vault) private view returns (int256 netCollateral) {
        int256 collateralBalance = int256(vault.collateral().balanceOf(address(vault)));
        int256 trackedCollateral = int256(vault.stableCollateralTotal()) +
            vault.getGlobalPositions().marginDepositedTotal;

        if (collateralBalance < trackedCollateral) revert FlatcoinErrors.InvariantViolation("collateralNet1");

        return collateralBalance - trackedCollateral;
    }

    function _globalAveragePriceIsNotNegative(IFlatcoinVault vault) private view {
        if (vault.getGlobalPositions().averagePrice < 0)
            revert FlatcoinErrors.InvariantViolation("globalAveragePriceIsNotNegative");
    }

    /// @dev Collateral balance changes should match tracked collateral changes
    function _collateralNetBalanceRemainsUnchanged(int256 netBefore, int256 netAfter) private pure {
        // Note: +1e6 to account for rounding errors.
        // This means we are ok with a small margin of error such that netAfter - 1e6 <= netBefore <= netAfter.
        if (netBefore > netAfter || netAfter > netBefore + 1e6)
            revert FlatcoinErrors.InvariantViolation("collateralNet2");
    }

    /// @dev Stable LPs should never lose value (can only gain on trading fees)
    function _stableCollateralPerShareIncreasesOrRemainsUnchanged(
        uint256 totalSupply,
        uint256 collateralPerShareBefore,
        uint256 collateralPerShareAfter
    ) private pure {
        // Note: +1 to account for rounding error
        if (totalSupply > 0 && collateralPerShareAfter + 1 < collateralPerShareBefore)
            revert FlatcoinErrors.InvariantViolation("stableCollateralPerShare");
    }

    /// @dev Stable LPs should be adjusted according to the liquidated position remaining margin and liquidation fee
    function _stableCollateralPerShareLiquidation(
        IStableModule stableModule,
        uint256 liquidationFee,
        int256 remainingMargin,
        uint256 stableCollateralPerShareBefore,
        uint256 stableCollateralPerShareAfter
    ) private view {
        uint256 totalSupply = stableModule.totalSupply();

        if (totalSupply == 0) return;

        int256 expectedStableCollateralPerShare;
        if (remainingMargin > 0) {
            if (remainingMargin > int256(liquidationFee)) {
                // position is healthy and there is a keeper fee taken from the margin
                // evaluate exact increase in stable collateral
                expectedStableCollateralPerShare =
                    int256(stableCollateralPerShareBefore) +
                    (((remainingMargin - int256(liquidationFee)) * 1e18) / int256(stableModule.totalSupply()));
            } else {
                // position has less or equal margin than liquidation fee
                // all the margin will go to the keeper and no change in stable collateral
                if (stableCollateralPerShareBefore != stableCollateralPerShareAfter)
                    revert FlatcoinErrors.InvariantViolation("stableCollateralPerShareLiquidation");

                return;
            }
        } else {
            // position is underwater and there is no keeper fee
            // evaluate exact decrease in stable collateral
            expectedStableCollateralPerShare =
                int256(stableCollateralPerShareBefore) +
                ((remainingMargin * 1e18) / int256(stableModule.totalSupply())); // underwater margin per share
        }
        if (
            expectedStableCollateralPerShare + 1e6 < int256(stableCollateralPerShareAfter) || // rounding error
            expectedStableCollateralPerShare - 1e6 > int256(stableCollateralPerShareAfter)
        ) revert FlatcoinErrors.InvariantViolation("stableCollateralPerShareLiquidation");
    }
}
