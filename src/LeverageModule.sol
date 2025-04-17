// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {DecimalMath} from "./libraries/DecimalMath.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";

import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {IControllerModule} from "./interfaces/IControllerModule.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IOrderAnnouncementModule} from "./interfaces/IOrderAnnouncementModule.sol";
import {IOrderExecutionModule} from "./interfaces/IOrderExecutionModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";

import "./interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;
import "./interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

/// @title LeverageModule
/// @author dHEDGE
/// @notice Contains functions to create/manage leverage positions.
/// @dev This module shouldn't hold any funds but can direct the vault to transfer funds.
contract LeverageModule is ILeverageModule, ModuleUpgradeable, ERC721EnumerableUpgradeable {
    using SafeCast for *;
    using DecimalMath for uint256;
    using SignedMath for int256;

    /////////////////////////////////////////////
    //                 Events                  //
    /////////////////////////////////////////////

    event LeverageOpen(
        address account,
        uint256 tokenId,
        uint256 entryPrice,
        uint256 margin,
        uint256 size,
        uint256 tradeFee
    );
    event LeverageAdjust(
        uint256 tokenId,
        uint256 averagePrice,
        uint256 adjustPrice,
        int256 marginDelta,
        int256 sizeDelta,
        uint256 tradeFee
    );
    event LeverageClose(
        uint256 tokenId,
        uint256 closePrice,
        LeverageModuleStructs.PositionSummary positionSummary,
        uint256 settledMargin,
        uint256 size,
        uint256 tradeFee
    );

    /////////////////////////////////////////////
    //                 Errors                  //
    /////////////////////////////////////////////

    error InvalidLeverageCriteria();
    error MarginTooSmall(uint256 marginMin, uint256 margin);
    error LeverageTooLow(uint256 leverageMin, uint256 leverage);
    error LeverageTooHigh(uint256 leverageMax, uint256 leverage);

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    /// @notice ERC721 token ID increment on mint.
    uint256 public tokenIdNext;

    /// @notice Leverage position criteria limits
    /// @notice A minimum margin limit adds a cost to create a position and ensures it can be liquidated at high leverage
    uint256 public marginMin;

    /// @notice Minimum leverage limit ensures that the position is valuable and adds long open interest
    uint256 public leverageMin;

    /// @notice Maximum leverage limit ensures that the position is safely liquidatable by keepers
    uint256 public leverageMax;

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
    function initialize(
        IFlatcoinVault vault_,
        uint256 marginMin_,
        uint256 leverageMin_,
        uint256 leverageMax_
    ) external initializer {
        __Module_init(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY, vault_);
        __ERC721_init("Flat Money Leveraged Positions", "LEV");

        _setLeverageCriteria(marginMin_, leverageMin_, leverageMax_);
    }

    /////////////////////////////////////////////
    //       Authorized Module Functions       //
    /////////////////////////////////////////////

    /// @notice Leverage open function. Mints ERC721 token receipt.
    /// @dev Has to be used in conjunction with the OrderExecution module.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending open leverage order.
    /// @param order_ The order to be executed.
    function executeOpen(
        address account_,
        DelayedOrderStructs.Order calldata order_
    ) external onlyAuthorizedModule returns (uint256 newTokenId_) {
        // Make sure the oracle price is after the order executability time
        uint32 maxAge = _getMaxAge(order_.executableAtTime);

        DelayedOrderStructs.AnnouncedLeverageOpen memory announcedOpen = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageOpen)
        );

        // Check that buy price doesn't exceed requested price.
        (uint256 entryPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            asset: address(vault.collateral()),
            maxAge: maxAge,
            priceDiffCheck: true
        });

        if (entryPrice > announcedOpen.maxFillPrice)
            revert ICommonErrors.HighSlippage(entryPrice, announcedOpen.maxFillPrice);

        vault.checkSkewMax({
            sizeChange: announcedOpen.additionalSize,
            stableCollateralChange: int256(announcedOpen.tradeFee)
        });

        {
            // The margin change is equal to funding fees accrued to longs and the margin deposited by the trader.
            vault.updateGlobalPositionData({
                price: entryPrice,
                marginDelta: int256(announcedOpen.margin),
                additionalSizeDelta: int256(announcedOpen.additionalSize)
            });

            newTokenId_ = _mint(account_);

            vault.setPosition(
                LeverageModuleStructs.Position({
                    averagePrice: entryPrice,
                    marginDeposited: announcedOpen.margin,
                    additionalSize: announcedOpen.additionalSize,
                    entryCumulativeFunding: IControllerModule(
                        vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)
                    ).cumulativeFundingRate()
                }),
                newTokenId_
            );
        }

        // Check that the new position isn't immediately liquidatable.
        if (
            ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)).canLiquidate(
                newTokenId_
            )
        ) revert ICommonErrors.PositionCreatesBadDebt();

        emit LeverageOpen(
            account_,
            newTokenId_,
            entryPrice,
            announcedOpen.margin,
            announcedOpen.additionalSize,
            announcedOpen.tradeFee
        );
    }

    /// @notice Leverage adjust function.
    /// @dev Needs to be used in conjunction with the OrderExecution module.
    /// @dev Note that a check has to be made in the calling module to ensure that
    ///      the position exists before calling this function.
    /// @param order_ The order to be executed.
    function executeAdjust(DelayedOrderStructs.Order calldata order_) external onlyAuthorizedModule {
        IOracleModule oracleModule = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY));
        uint32 maxAge = _getMaxAge(order_.executableAtTime);

        DelayedOrderStructs.AnnouncedLeverageAdjust memory announcedAdjust = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageAdjust)
        );

        LeverageModuleStructs.Position memory position = vault.getPosition(announcedAdjust.tokenId);

        (uint256 adjustPrice, ) = oracleModule.getPrice({
            asset: address(vault.collateral()),
            maxAge: maxAge,
            priceDiffCheck: true
        });

        int256 cumulativeFunding = IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY))
            .cumulativeFundingRate();

        // Prevent adjustment if the position is underwater.
        if (getPositionSummary(vault.getPosition(announcedAdjust.tokenId), adjustPrice).marginAfterSettlement <= 0)
            revert ICommonErrors.ValueNotPositive("marginAfterSettlement");

        // Fees come out from the margin if the margin is being reduced or remains unchanged (meaning the size is being modified).
        int256 marginAdjustment = (announcedAdjust.marginAdjustment > 0)
            ? announcedAdjust.marginAdjustment
            : announcedAdjust.marginAdjustment - int256(announcedAdjust.totalFee);

        // This accounts for the profit loss and funding fees accrued till now.
        int256 newMargin = marginAdjustment + int256(position.marginDeposited);

        uint256 newAdditionalSize = (int256(position.additionalSize) + announcedAdjust.additionalSizeAdjustment)
            .toUint256();

        uint256 newEntryPrice;

        if (announcedAdjust.additionalSizeAdjustment >= 0) {
            // Size is being increased. Adjust the entry price to the average entry price.

            if (adjustPrice > announcedAdjust.fillPrice)
                revert ICommonErrors.HighSlippage(adjustPrice, announcedAdjust.fillPrice);

            uint256 newEntryAmount = position.averagePrice *
                position.additionalSize +
                adjustPrice *
                uint256(announcedAdjust.additionalSizeAdjustment);

            // In case there is a rounding error, we round up the entry price as this will ensure the traders don't get extra
            // margin after settlement of the position.
            newEntryPrice = (newEntryAmount % newAdditionalSize != 0)
                ? newEntryAmount / newAdditionalSize + 1
                : newEntryAmount / newAdditionalSize;
        } else {
            // Size is being decreased. Keep the same entry price.

            if (adjustPrice < announcedAdjust.fillPrice)
                revert ICommonErrors.HighSlippage(adjustPrice, announcedAdjust.fillPrice);

            int256 partialPnLEarned = (-announcedAdjust.additionalSizeAdjustment *
                (int256(adjustPrice) - int256(position.averagePrice))) / int256(adjustPrice);

            newMargin += partialPnLEarned;
            newEntryPrice = position.averagePrice;

            // The margin being updated in the global position should also account for the pnl being settled for
            // partial closure of the position.
            marginAdjustment += partialPnLEarned;

            // Since position size decrease is akin to partial closure of the position, we have to settle the profit loss
            // associated with this position size. The settlement involves increasing/decreasing the stable collateral total
            // as LPs are the counterparty to each leverage position.
            vault.updateStableCollateralTotal(-partialPnLEarned);
        }

        // Entry cumulative funding is adjusted to account for the new size.
        // So that the position accumulated funding is not affected after adjustment.
        int256 newEntryCumulativeFunding = position.entryCumulativeFunding +
            (((cumulativeFunding - position.entryCumulativeFunding) * announcedAdjust.additionalSizeAdjustment) /
                int256(newAdditionalSize));

        // Check that the leverage isn't too high.
        checkLeverageCriteria(newMargin.toUint256(), newAdditionalSize);

        vault.updateGlobalPositionData({
            price: (announcedAdjust.additionalSizeAdjustment < 0) ? position.averagePrice : adjustPrice,
            marginDelta: marginAdjustment,
            additionalSizeDelta: announcedAdjust.additionalSizeAdjustment
        });

        vault.setPosition(
            LeverageModuleStructs.Position({
                averagePrice: newEntryPrice,
                marginDeposited: newMargin.toUint256(),
                additionalSize: newAdditionalSize,
                entryCumulativeFunding: newEntryCumulativeFunding
            }),
            announcedAdjust.tokenId
        );

        // Check that the new position isn't immediately liquidatable.
        if (
            ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)).canLiquidate(
                announcedAdjust.tokenId,
                adjustPrice
            )
        ) revert ICommonErrors.PositionCreatesBadDebt();

        emit LeverageAdjust(
            announcedAdjust.tokenId,
            newEntryPrice,
            adjustPrice,
            marginAdjustment,
            announcedAdjust.additionalSizeAdjustment,
            announcedAdjust.tradeFee
        );
    }

    /// @notice Leverage close function.
    /// @dev Needs to be used in conjunction with the OrderExecution module.
    /// @dev Note that a check has to be made in the calling module to ensure that
    ///      the position exists before calling this function.
    /// @param order_ The order to be executed.
    function executeClose(
        DelayedOrderStructs.Order calldata order_
    ) external onlyAuthorizedModule returns (uint256 marginAfterPositionClose_) {
        IOracleModule oracleModule = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY));
        DelayedOrderStructs.AnnouncedLeverageClose memory announcedClose = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageClose)
        );

        LeverageModuleStructs.Position memory position = vault.getPosition(announcedClose.tokenId);

        // Make sure the oracle price is after the order executability time
        uint32 maxAge = _getMaxAge(order_.executableAtTime);

        // check that sell price doesn't exceed requested price
        (uint256 exitPrice, ) = oracleModule.getPrice({
            asset: address(vault.collateral()),
            maxAge: maxAge,
            priceDiffCheck: true
        });
        if (exitPrice < announcedClose.minFillPrice)
            revert ICommonErrors.HighSlippage(exitPrice, announcedClose.minFillPrice);

        uint256 totalFee;
        int256 settledMargin;
        LeverageModuleStructs.PositionSummary memory positionSummary;
        {
            positionSummary = getPositionSummary(position, exitPrice);

            settledMargin = positionSummary.marginAfterSettlement;
            totalFee = announcedClose.tradeFee + order_.keeperFee;

            if (settledMargin <= 0) revert ICommonErrors.ValueNotPositive("settledMargin");
            // Make sure there is enough margin in the position to pay the keeper fee
            if (settledMargin < int256(totalFee)) revert ICommonErrors.NotEnoughMarginForFees(settledMargin, totalFee);

            vault.updateStableCollateralTotal(-positionSummary.profitLoss); // pay the trade fee to stable LPs

            vault.updateGlobalPositionData({
                price: position.averagePrice,
                marginDelta: -(int256(position.marginDeposited) + positionSummary.accruedFunding),
                additionalSizeDelta: -int256(position.additionalSize)
            });

            // Delete position storage
            vault.deletePosition(announcedClose.tokenId);
        }

        burn(announcedClose.tokenId);

        emit LeverageClose(
            announcedClose.tokenId,
            exitPrice,
            positionSummary,
            uint256(settledMargin),
            position.additionalSize,
            announcedClose.tradeFee
        );

        return uint256(settledMargin);
    }

    /// @notice Mints an ERC721 token representing a leverage position.
    /// @param to_ The address to mint the token to.
    /// @return tokenId_ The ERC721 token ID of the leverage position.
    function mint(address to_) public onlyAuthorizedModule returns (uint256 tokenId_) {
        tokenId_ = _mint(to_);
    }

    /// @notice Burns the ERC721 token representing the leverage position.
    /// @param tokenId_ The ERC721 token ID of the leverage position.
    function burn(uint256 tokenId_) public onlyAuthorizedModule {
        _burn(tokenId_);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Returns the summary of a position using the current price.
    /// @dev Note that this function would most often use the onchain oracle price to calculate the position summary.
    /// @param tokenId_ The ERC721 token ID of the position.
    /// @return positionSummary_ The summary of the position.
    function getPositionSummary(
        uint256 tokenId_
    ) external view returns (LeverageModuleStructs.PositionSummary memory positionSummary_) {
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice(
            address(vault.collateral())
        );

        return getPositionSummary(vault.getPosition(tokenId_), currentPrice);
    }

    /// @dev Summarises a positions' earnings/losses.
    /// @param position_ The position to summarise.
    /// @param price_ The current price of the collateral asset.
    /// @return positionSummary_ The summary of the position.
    function getPositionSummary(
        LeverageModuleStructs.Position memory position_,
        uint256 price_
    ) public view returns (LeverageModuleStructs.PositionSummary memory positionSummary_) {
        IControllerModule perpController = IControllerModule(
            vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)
        );

        int256 profitLossOfPosition = perpController.profitLoss(position_, price_);
        int256 accruedFundingOfPosition = perpController.accruedFunding(position_);

        return
            LeverageModuleStructs.PositionSummary({
                profitLoss: profitLossOfPosition,
                accruedFunding: accruedFundingOfPosition,
                marginAfterSettlement: int256(position_.marginDeposited) +
                    profitLossOfPosition +
                    accruedFundingOfPosition
            });
    }

    /// @notice Asserts that the position to be opened meets margin and size criteria.
    /// @param margin_ The margin to be deposited.
    /// @param size_ The size of the position.
    function checkLeverageCriteria(uint256 margin_, uint256 size_) public view {
        uint256 leverage = ((margin_ + size_) * 1e18) / margin_;

        if (leverage < leverageMin) revert LeverageTooLow(leverageMin, leverage);
        if (leverage > leverageMax) revert LeverageTooHigh(leverageMax, leverage);
        if (margin_ < marginMin) revert MarginTooSmall(marginMin, margin_);
    }

    /////////////////////////////////////////////
    //       Internal/Private Functions        //
    /////////////////////////////////////////////

    /// @notice Handles incrementing the tokenIdNext and minting the nft
    /// @param to_ the minter's address
    /// @return tokenId_ the tokenId of the new NFT.
    function _mint(address to_) internal returns (uint256 tokenId_) {
        tokenId_ = tokenIdNext;

        _safeMint(to_, tokenIdNext);

        tokenIdNext += 1;
    }

    /// @notice Before token transfer hook.
    /// @dev Only reverts if there is existing order corresponding to the token ID and only if the action is a transfer.
    ///      When the token ID is burnt, any associated orders are deleted.
    /// @param to_ The address to transfer token to.
    /// @param tokenId_ The ERC721 token ID to transfer.
    /// @param auth_ See OZ _update function <https://docs.openzeppelin.com/contracts/5.x/api/token/erc721#ERC721-_update-address-uint256-address->
    function _update(address to_, uint256 tokenId_, address auth_) internal virtual override returns (address from) {
        address tokenOwner = _ownerOf(tokenId_);
        IOrderAnnouncementModule orderAnnouncementModule = IOrderAnnouncementModule(
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
        );

        // Ignore the checks if a new position is being minted because the `tokenOwner` of the `tokenId_` is address(0) only
        // in that case.
        if (tokenOwner != address(0)) {
            DelayedOrderStructs.Order memory normalOrder = orderAnnouncementModule.getAnnouncedOrder(tokenOwner);
            DelayedOrderStructs.Order memory limitOrder = orderAnnouncementModule.getLimitOrder(tokenId_);

            // We need to perform additional checks only in case there exists an order associated with the token owner
            // and the order type is a leverage adjust, leverage close or a limit order associated with this token ID.
            // In other cases, we can proceed with the transfer.
            if (
                normalOrder.orderType == DelayedOrderStructs.OrderType.LeverageAdjust ||
                normalOrder.orderType == DelayedOrderStructs.OrderType.LeverageClose
            ) {
                // Decode the order data to check if the order belongs to `tokenId_`.
                if (normalOrder.orderType == DelayedOrderStructs.OrderType.LeverageAdjust) {
                    DelayedOrderStructs.AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(
                        normalOrder.orderData,
                        (DelayedOrderStructs.AnnouncedLeverageAdjust)
                    );

                    if (leverageAdjust.tokenId == tokenId_) {
                        // If the token is being burnt then cancel the existing order associated with it.
                        // This is because there might be funds locked in the execution module that need to be refunded.
                        if (to_ == address(0)) {
                            IOrderExecutionModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY))
                                .cancelOrderByModule(tokenOwner);
                        } else {
                            // Otherwise, disallow the transfer.
                            revert ICommonErrors.OrderExists(normalOrder.orderType);
                        }
                    }
                } else {
                    DelayedOrderStructs.AnnouncedLeverageClose memory leverageClose = abi.decode(
                        normalOrder.orderData,
                        (DelayedOrderStructs.AnnouncedLeverageClose)
                    );

                    if (leverageClose.tokenId == tokenId_) {
                        // If the token is being burnt then delete the order.
                        // There are no funds locked in the execution module that need to be refunded.
                        if (to_ == address(0)) {
                            IOrderAnnouncementModule(
                                vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
                            ).deleteOrder(tokenOwner);
                        } else {
                            // Otherwise, disallow the transfer.
                            revert ICommonErrors.OrderExists(normalOrder.orderType);
                        }
                    }
                }
            }

            if (limitOrder.orderType != DelayedOrderStructs.OrderType.None) {
                // If a limit order associated with the token ID exists and the token is being burnt then delete the order.
                // There are no funds locked in the execution module that need to be refunded.
                if (to_ == address(0)) {
                    IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                        .deleteLimitOrder(tokenId_);
                } else {
                    // Otherwise, disallow the transfer.
                    revert ICommonErrors.OrderExists(limitOrder.orderType);
                }
            }
        }

        return super._update(to_, tokenId_, auth_);
    }

    /// @notice Setter for the leverage position criteria limits.
    /// @dev The limits are used to ensure that the position is valuable and there is an incentive to liquidate it.
    /// @param marginMin_ The new minimum margin limit.
    /// @param leverageMin_ The new minimum leverage limit.
    /// @param leverageMax_ The new maximum leverage limit.
    function _setLeverageCriteria(uint256 marginMin_, uint256 leverageMin_, uint256 leverageMax_) private {
        if (leverageMax_ <= leverageMin_) revert InvalidLeverageCriteria();

        marginMin = marginMin_;
        leverageMin = leverageMin_;
        leverageMax = leverageMax_;
    }

    /// @notice Returns the maximum age of the oracle price to be used.
    /// @param executableAtTime_ The time at which the order is executable.
    /// @return maxAge_ The maximum age of the oracle price to be used.
    function _getMaxAge(uint64 executableAtTime_) internal view returns (uint32 maxAge_) {
        return (block.timestamp - executableAtTime_).toUint32();
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Setter for the leverage position criteria limits.
    /// @dev The limits are used to ensure that the position is valuable and there is an incentive to liquidate it.
    /// @param marginMin_ The new minimum margin limit.
    /// @param leverageMin_ The new minimum leverage limit.
    /// @param leverageMax_ The new maximum leverage limit.
    function setLeverageCriteria(uint256 marginMin_, uint256 leverageMin_, uint256 leverageMax_) external onlyOwner {
        _setLeverageCriteria(marginMin_, leverageMin_, leverageMax_);
    }
}
