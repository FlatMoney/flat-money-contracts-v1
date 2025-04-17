// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ControllerBase} from "./abstracts/ControllerBase.sol";

import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";

import "./interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

/// @title OptionsControllerModule
/// @author dHEDGE
/// @notice Controller module for the options markets.
contract OptionsControllerModule is ControllerBase {
    uint8 public constant CONTROLLER_TYPE = 2;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    function initialize(
        IFlatcoinVault vault_,
        uint256 maxFundingVelocity_,
        uint256 maxVelocitySkew_,
        uint256 targetSizeCollateralRatio_,
        int256 minFundingRate_
    ) external {
        __ControllerBase_init(
            vault_,
            maxFundingVelocity_,
            maxVelocitySkew_,
            targetSizeCollateralRatio_,
            minFundingRate_
        );
    }

    /////////////////////////////////////////////
    //         Public Overriden Functions      //
    /////////////////////////////////////////////

    /// @notice Returns the PnL in terms of the market currency (eg. ETH/LST) and not in dollars ($).
    ///      This function rounds down the PnL to avoid rounding errors when subtracting individual PnLs
    ///      from the global `marginDepositedTotal` value when closing the position.
    /// @param position_ The position to calculate the PnL for.
    /// @param price_ The current price of the collateral asset.
    /// @return pnl_ The PnL in terms of the market currency (eg. ETH/LST) and not in dollars ($).
    function profitLoss(
        LeverageModuleStructs.Position memory position_,
        uint256 price_
    ) public pure override returns (int256 pnl_) {
        int256 priceShift = price_ > position_.averagePrice
            ? int256(price_) - int256(position_.averagePrice)
            : int256(0);

        return (int256(position_.additionalSize) * (priceShift)) / int256(price_);
    }

    /// @notice Returns the PnL in terms of the market currency (eg. ETH/LST) and not in dollars ($).
    ///      The function iterates through all open positions and calculates the PnL for each position
    ///      to aggregate the total PnL in the system.
    /// @param price_ The current price of the collateral asset.
    /// @return pnl_ The PnL in terms of the market currency (eg. ETH/LST) and not in dollars ($).
    function profitLossTotal(uint256 price_) public view override returns (int256 pnl_) {
        uint256[] memory _openPositionIds = vault.getMaxPositionIds();

        for (uint256 i; i < _openPositionIds.length; ++i) {
            LeverageModuleStructs.Position memory position = vault.getPosition(_openPositionIds[i]);
            pnl_ += profitLoss(position, price_);
        }
    }
}
