// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {DecimalMath} from "../libraries/DecimalMath.sol";
import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";
import {IControllerModule} from "../interfaces/IControllerModule.sol";
import {ILeverageModule} from "../interfaces/ILeverageModule.sol";
import {IStableModule} from "../interfaces/IStableModule.sol";
import {IOracleModule} from "../interfaces/IOracleModule.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";
import {IOrderAnnouncementModule} from "../interfaces/IOrderAnnouncementModule.sol";
import {IViewer} from "../interfaces/IViewer.sol";

import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";

import "../interfaces/structs/ViewerStructs.sol" as ViewerStructs;
import "../interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "../interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;
import "../interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

/// @title ViewerBase
/// @author dHEDGE
/// @notice Contains functions to view details about market and its positions.
/// @dev WARNING: Should only be used by 3rd party integrations and frontends.
abstract contract ViewerBase is IViewer {
    using SafeCast for *;
    using SignedMath for int256;
    using DecimalMath for int256;
    using DecimalMath for uint256;

    IFlatcoinVault public vault;

    constructor(IFlatcoinVault vault_) {
        vault = vault_;
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    function getAccountLeveragePositionData(
        address account_
    ) external view virtual returns (ViewerStructs.LeveragePositionData[] memory positionData_) {
        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        uint256 balance = leverageModule.balanceOf(account_);
        positionData_ = new ViewerStructs.LeveragePositionData[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = leverageModule.tokenOfOwnerByIndex(account_, i);
            positionData_[i] = getPositionData(tokenId);
        }
    }

    /// @notice Returns leverage position data for a range of position IDs
    /// @dev For a closed position, the token is burned and position data will be 0
    function getPositionData(
        uint256 tokenIdFrom_,
        uint256 tokenIdTo_
    ) external view virtual returns (ViewerStructs.LeveragePositionData[] memory positionData_) {
        uint256 length = tokenIdTo_ - tokenIdFrom_ + 1;
        positionData_ = new ViewerStructs.LeveragePositionData[](length);

        for (uint256 i = 0; i < length; i++) {
            positionData_[i] = getPositionData(i + tokenIdFrom_);
        }
    }

    /// @notice Returns leverage position data for a specific position ID
    /// @dev For a closed position, the token is burned and position data will be 0
    function getPositionData(
        uint256 tokenId_
    ) public view virtual returns (ViewerStructs.LeveragePositionData memory positionData_) {
        IOrderAnnouncementModule orderAnnouncementModule = IOrderAnnouncementModule(
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
        );

        LeverageModuleStructs.Position memory position = vault.getPosition(tokenId_);

        (uint256 marketPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        LeverageModuleStructs.PositionSummary memory positionSummary = ILeverageModule(
            vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)
        ).getPositionSummary(position, marketPrice);

        uint256 limitOrderStopLossPrice;
        uint256 limitOrderProfitTakePrice;

        {
            DelayedOrderStructs.Order memory order = orderAnnouncementModule.getLimitOrder(tokenId_);

            if (order.orderType == DelayedOrderStructs.OrderType.LimitClose) {
                DelayedOrderStructs.AnnouncedLimitClose memory limitClose = abi.decode(
                    order.orderData,
                    (DelayedOrderStructs.AnnouncedLimitClose)
                );

                limitOrderStopLossPrice = limitClose.stopLossPrice;
                limitOrderProfitTakePrice = limitClose.profitTakePrice;
            }
        }

        uint256 liqPrice = liquidationPrice(tokenId_);

        positionData_ = ViewerStructs.LeveragePositionData({
            tokenId: tokenId_,
            averagePrice: position.averagePrice,
            marginDeposited: position.marginDeposited,
            additionalSize: position.additionalSize,
            entryCumulativeFunding: position.entryCumulativeFunding,
            profitLoss: positionSummary.profitLoss,
            accruedFunding: positionSummary.accruedFunding,
            marginAfterSettlement: positionSummary.marginAfterSettlement,
            liquidationPrice: liqPrice,
            limitOrderStopLossPrice: limitOrderStopLossPrice,
            limitOrderProfitTakePrice: limitOrderProfitTakePrice
        });
    }

    function getFlatcoinTVL() external view virtual returns (uint256 tvl_) {
        IOracleModule oracleModule = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY));

        (uint256 price, ) = oracleModule.getPrice(address(vault.collateral()));
        tvl_ = (vault.stableCollateralTotal() * price) / (10 ** IERC20Metadata(vault.collateral()).decimals());
    }

    function getMarketSummary()
        external
        view
        virtual
        returns (LeverageModuleStructs.MarketSummary memory marketSummary_)
    {
        (uint256 price, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        marketSummary_ = getMarketSummary(price);
    }

    /// @dev Summarises the market state which is used in other functions.
    /// @param price_ The current price of the collateral asset.
    /// @return marketSummary_ The summary of the market.
    function getMarketSummary(
        uint256 price_
    ) public view virtual returns (LeverageModuleStructs.MarketSummary memory marketSummary_) {
        IControllerModule controllerModule = IControllerModule(
            vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)
        );

        return
            LeverageModuleStructs.MarketSummary({
                profitLossTotalByLongs: controllerModule.profitLossTotal(price_),
                accruedFundingTotalByLongs: controllerModule.accruedFundingTotalByLongs(),
                currentFundingRate: controllerModule.currentFundingRate(),
                nextFundingEntry: controllerModule.nextFundingEntry()
            });
    }

    /// @notice Function to get a summary of the vault.
    /// @dev This can be used by modules to get the current state of the vault.
    /// @dev Note that the `marketSkew` returned doesn't account for funding rate influence.
    /// @return vaultSummary_ The vault summary struct.
    function getVaultSummary() external view virtual returns (FlatcoinVaultStructs.VaultSummary memory vaultSummary_) {
        IControllerModule controllerModule = IControllerModule(
            vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)
        );

        uint256 stableCollateralTotal = vault.stableCollateralTotal();
        FlatcoinVaultStructs.GlobalPositions memory globalPositions = vault.getGlobalPositions();

        return
            FlatcoinVaultStructs.VaultSummary({
                marketSkew: int256(vault.getGlobalPositions().sizeOpenedTotal) - int256(vault.stableCollateralTotal()),
                cumulativeFundingRate: controllerModule.cumulativeFundingRate(),
                lastRecomputedFundingRate: controllerModule.lastRecomputedFundingRate(),
                lastRecomputedFundingTimestamp: controllerModule.lastRecomputedFundingTimestamp(),
                stableCollateralTotal: stableCollateralTotal,
                globalPositions: globalPositions
            });
    }

    /// @notice Returns the market skew in percentage terms.
    /// @return skewPercent_ The market skew in percentage terms [-1e18, (1 - skewFractionMax)*1e18].
    /// @dev When the `skewPercent_` is -1e18 it means the market is fully skewed towards stable LPs.
    ///      When the `skewPercent_` is (1 - skewFractionMax)*1e18 it means the market is skewed max towards leverage LPs.
    ///      When the `skewPercent_` is 0 it means the market is either perfectly hedged or there is no stable collateral.
    /// @dev Note that this `skewPercent_` is relative to the stable collateral.
    ///      So it's max value is (1 - skewFractionMax)*1e18. For example, if the `skewFractionMax` is 1.2e18,
    ///      the max value of `skewPercent_` is 0.2e18. This means that the market is skewed 20% towards leverage LPs
    ///      relative to the stable collateral.
    function getMarketSkewPercentage() external view virtual returns (int256 skewPercent_) {
        int256 marketSkew = IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY))
            .getCurrentSkew();
        uint256 stableCollateralTotal = vault.stableCollateralTotal();

        // Technically, the market skew is undefined when there are no open positions.
        // Since no leverage position can be opened when there is no stable collateral in the vault,
        // it also means stable collateral == leverage long margin and hence no skew.
        if (stableCollateralTotal == 0) {
            return 0;
        } else {
            return marketSkew._divideDecimal(int256(stableCollateralTotal));
        }
    }

    function getFlatcoinPriceInUSD() external view virtual returns (uint256 priceInUSD_) {
        IERC20Metadata collateralToken = IERC20Metadata(vault.collateral());
        IStableModule stableModule = IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY));
        uint256 tokenPriceInCollateral = stableModule.stableCollateralPerShare();
        (uint256 collateralPriceInUSD, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
            .getPrice(address(collateralToken));

        uint256 collateralDecimals = collateralToken.decimals();

        if (collateralDecimals > 18) {
            tokenPriceInCollateral /= 10 ** (collateralDecimals - 18);
        } else {
            tokenPriceInCollateral *= 10 ** (18 - collateralDecimals);
        }

        priceInUSD_ = (tokenPriceInCollateral * collateralPriceInUSD) / 1e18;
    }

    /////////////////////////////////////////////
    //         Liquidation Price Functions     //
    /////////////////////////////////////////////

    /// @notice Function to calculate liquidation price for a given position.
    /// @dev The collateral price is assumed to be constant.
    /// @dev Note that liquidation price is influenced by the funding rates and also the current price.
    /// @param tokenId_ The token ID of the leverage position.
    /// @return liqPrice_ The liquidation price of the position in $ terms.
    function liquidationPrice(uint256 tokenId_) public view virtual returns (uint256 liqPrice_) {
        (uint256 collateralPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
            .getPrice(address(vault.collateral()));

        return liquidationPrice({tokenId_: tokenId_, collateralPrice_: collateralPrice});
    }

    /// @notice Function to calculate liquidation price for a given position at a given collateral price.
    /// @dev Note that liquidation price is influenced by the funding rates and also the current price.
    /// @param tokenId_ The token ID of the leverage position.
    /// @param collateralPrice_ The collateral token price at which the liquidation price is to be calculated.
    /// @return liqPrice_ The liquidation price of the position in $ terms.
    function liquidationPrice(
        uint256 tokenId_,
        uint256 collateralPrice_
    ) public view virtual returns (uint256 liqPrice_) {
        LeverageModuleStructs.Position memory position = vault.getPosition(tokenId_);

        if (position.additionalSize == 0) {
            return 0;
        }

        int256 accruedFunding = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY))
            .getPositionSummary(position, collateralPrice_)
            .accruedFunding;

        int256 result = _calcLiquidationPrice({
            position_: position,
            accruedFunding_: accruedFunding,
            liquidationMargin_: ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY))
                .getLiquidationMargin(position.additionalSize, collateralPrice_)
        });

        return (result > 0) ? uint256(result) : 0;
    }

    /////////////////////////////////////////////
    //          Internal Functions             //
    /////////////////////////////////////////////

    /// @dev Calculates the liquidation price for a market with market asset and collateral asset being the same.
    /// @param position_ The position to calculate the liquidation price for.
    /// @param accruedFunding_ The accrued funding of the position.
    /// @param liquidationMargin_ The liquidation margin.
    /// @return liqPrice_ The liquidation price.
    function _calcLiquidationPrice(
        LeverageModuleStructs.Position memory position_,
        int256 accruedFunding_,
        uint256 liquidationMargin_
    ) internal pure virtual returns (int256 liqPrice_) {
        // A position can be liquidated whenever:- remainingMargin <= liquidationMargin
        //
        // Calculating the liquidation price based on a given liquidationMargin can be done as follows:
        //
        // liquidationMargin = margin + profitLoss + funding
        // liquidationMargin = margin + [(price - entryPrice) * positionSize / price] + funding
        // liquidationMargin - (margin + funding) = [(price - entryPrice) * positionSize / price]
        // liquidationMargin - (margin + funding) = positionSize - (entryPrice * positionSize / price)
        // positionSize - liquidationMargin + margin + funding = entryPrice * positionSize / price
        // price = entryPrice * positionSize / (positionSize - liquidationMargin + margin + funding)
        //
        // In our case, positionSize = position.additionalSize.
        // Note: If there are bounds on `liquidationFee` and/or `keeperFee` then this formula doesn't yield an accurate liquidation price.
        // This is because, when the position size is too large such that liquidation fee for that position has to be bounded we are essentially
        // solving the following equation:
        // LiquidationBuffer + (LiquidationUpperBound / Price) + KeeperFee = Margin + (Price - EntryPrice)*PositionSize + AccruedFunding
        // And according to Wolfram Alpha, this equation cannot be solved for Price (at least trivially):
        // https://www.wolframalpha.com/input?i=A+++(B+/+X)+%3D+C+++(X+-+D)+*+E+,+X+%3E+0,+Solution+for+variable+X
        return
            int256((position_.additionalSize * position_.averagePrice)) /
            (int256(position_.additionalSize + position_.marginDeposited) +
                accruedFunding_ -
                int256(liquidationMargin_));
    }
}
