// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";

import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {FeeManager} from "./abstracts/FeeManager.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IOrderAnnouncementModule} from "./interfaces/IOrderAnnouncementModule.sol";
import {IOrderExecutionModule} from "./interfaces/IOrderExecutionModule.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IStableModule} from "./interfaces/IStableModule.sol";
import {IControllerModule} from "./interfaces/IControllerModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";
import {IKeeperFee} from "./interfaces/IKeeperFee.sol";

import "./interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

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
    event OrderAnnounced(address account, DelayedOrderStructs.OrderType orderType, uint256 keeperFee);
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
    mapping(address account => DelayedOrderStructs.Order order) private _announcedOrder;

    /// @dev Mapping containing all the limit orders in an encoded format.
    mapping(uint256 tokenId => DelayedOrderStructs.Order order) private _limitOrder;

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

        _announcedOrder[receiver_] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.StableDeposit,
            orderData: abi.encode(
                DelayedOrderStructs.AnnouncedStableDeposit({
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

        emit OrderAnnounced({
            account: receiver_,
            orderType: DelayedOrderStructs.OrderType.StableDeposit,
            keeperFee: keeperFee_
        });
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

        _announcedOrder[msg.sender] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.StableWithdraw,
            orderData: abi.encode(
                DelayedOrderStructs.AnnouncedStableWithdraw({
                    withdrawAmount: withdrawAmount_,
                    minAmountOut: minAmountOut_
                })
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        // Lock the LP tokens belonging to this position so that it can't be transferred to someone else.
        // Locking doesn't require an approval from an account.
        stableModule.lock({account: msg.sender, amount: withdrawAmount_});

        emit OrderAnnounced({
            account: msg.sender,
            orderType: DelayedOrderStructs.OrderType.StableWithdraw,
            keeperFee: keeperFee_
        });
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

        _announcedOrder[receiver_] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.LeverageOpen,
            orderData: abi.encode(
                DelayedOrderStructs.AnnouncedLeverageOpen({
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

        emit OrderAnnounced({
            account: receiver_,
            orderType: DelayedOrderStructs.OrderType.LeverageOpen,
            keeperFee: keeperFee_
        });
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

        _announcedOrder[msg.sender] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.LeverageAdjust,
            orderData: abi.encode(
                DelayedOrderStructs.AnnouncedLeverageAdjust({
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

        emit OrderAnnounced({
            account: msg.sender,
            orderType: DelayedOrderStructs.OrderType.LeverageAdjust,
            keeperFee: keeperFee_
        });
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

        _announcedOrder[msg.sender] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.LeverageClose,
            orderData: abi.encode(
                DelayedOrderStructs.AnnouncedLeverageClose({
                    tokenId: tokenId_,
                    minFillPrice: minFillPrice_,
                    tradeFee: tradeFee
                })
            ),
            keeperFee: keeperFee_,
            executableAtTime: executableAtTime
        });

        emit OrderAnnounced({
            account: msg.sender,
            orderType: DelayedOrderStructs.OrderType.LeverageClose,
            keeperFee: keeperFee_
        });
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

        if (_limitOrder[tokenId_].orderType == DelayedOrderStructs.OrderType.None) revert LimitOrderInvalid(tokenId_);

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
        if (_limitOrder[tokenId_].orderType == DelayedOrderStructs.OrderType.LimitClose) {
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
    function getAnnouncedOrder(address account_) external view returns (DelayedOrderStructs.Order memory order_) {
        return _announcedOrder[account_];
    }

    /// @notice Getter for the announced limit order of a token ID
    /// @param tokenId_ The ERC721 token ID of the position
    /// @return order_ The order struct
    function getLimitOrder(uint256 tokenId_) external view returns (DelayedOrderStructs.Order memory order_) {
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

        _limitOrder[tokenId_] = DelayedOrderStructs.Order({
            orderType: DelayedOrderStructs.OrderType.LimitClose,
            orderData: abi.encode(DelayedOrderStructs.AnnouncedLimitClose(tokenId_, stopLossPrice_, profitTakePrice_)),
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
