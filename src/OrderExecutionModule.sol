// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {FeeManager} from "./abstracts/FeeManager.sol";
import {OracleModifiers} from "./abstracts/OracleModifiers.sol";
import {InvariantChecks} from "./abstracts/InvariantChecks.sol";

import {IOrderExecutionModule} from "./interfaces/IOrderExecutionModule.sol";
import {IOrderAnnouncementModule} from "./interfaces/IOrderAnnouncementModule.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IStableModule} from "./interfaces/IStableModule.sol";
import {IKeeperFee} from "./interfaces/IKeeperFee.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {IControllerModule} from "./interfaces/IControllerModule.sol";
import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import "./interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

/// @title OrderExecutionModule
/// @author dHEDGE
/// @notice Contract for executing delayed orders.
contract OrderExecutionModule is
    IOrderExecutionModule,
    ModuleUpgradeable,
    ReentrancyGuardUpgradeable,
    InvariantChecks,
    OracleModifiers
{
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IStableModule;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event OrderCancelled(address account, DelayedOrderStructs.OrderType orderType);
    event OrderExecuted(address account, DelayedOrderStructs.OrderType orderType, uint256 keeperFee);
    event LimitOrderExecuted(uint256 tokenId, LimitOrderExecutionType executionType);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error OrderHasExpired();
    error OrderHasNotExpired();
    error OrderInvalid(address account);
    error LimitOrderPriceNotInRange(uint256 price, uint256 stopLossPrice, uint256 profitTakePrice);

    /////////////////////////////////////////////
    //              Enums & Structs            //
    /////////////////////////////////////////////

    enum LimitOrderExecutionType {
        None, // 0
        StopLoss, // 1
        ProfitTake // 2
    }

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    /// @notice The maximum amount of time that can expire between trade announcement and execution.
    uint64 public maxExecutabilityAge;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the OrderExecutionModule with the Vault address.
    /// @param vault_ The address of the FlatcoinVault contract.
    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function initialize(IFlatcoinVault vault_, uint64 maxExecutabilityAge_) external initializer {
        __Module_init(FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY, vault_);
        __ReentrancyGuard_init();

        _setMaxExecutabilityAge(maxExecutabilityAge_);
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    /// @notice Executes any valid pending order for an account.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending deposit.
    /// @param priceUpdateData_ The Pyth network offchain price oracle update data.
    function executeOrder(
        address account_,
        bytes[] calldata priceUpdateData_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updatePythPrice(vault, msg.sender, priceUpdateData_)
        orderInvariantChecks(vault)
    {
        DelayedOrderStructs.Order memory order = _getAnnouncedOrder(account_);

        if (order.orderType == DelayedOrderStructs.OrderType.None) revert OrderInvalid(account_);

        _prepareExecutionOrder(account_, order.executableAtTime);

        // Settle funding fees before executing any order.
        // This is to avoid error related to max caps or max skew reached when the market has been skewed to one side for a long time.
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        vault.checkGlobalMarginPositive();

        if (order.orderType == DelayedOrderStructs.OrderType.StableDeposit) {
            _executeStableDeposit(account_, order);
        } else if (order.orderType == DelayedOrderStructs.OrderType.StableWithdraw) {
            _executeStableWithdraw(account_, order);
        } else if (order.orderType == DelayedOrderStructs.OrderType.LeverageOpen) {
            _executeLeverageOpen(account_, order);
        } else if (order.orderType == DelayedOrderStructs.OrderType.LeverageClose) {
            _executeLeverageClose(account_, order);
        } else if (order.orderType == DelayedOrderStructs.OrderType.LeverageAdjust) {
            _executeLeverageAdjust(account_, order);
        }

        emit OrderExecuted({account: account_, orderType: order.orderType, keeperFee: order.keeperFee});
    }

    /// @notice Function to execute a limit order
    /// @dev This function is typically called by the keeper
    /// @param tokenId_ The token ID of the leverage position.
    /// @param priceUpdateData_ The Pyth network offchain price oracle update data.
    function executeLimitOrder(
        uint256 tokenId_,
        bytes[] calldata priceUpdateData_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        updatePythPrice(vault, msg.sender, priceUpdateData_)
        orderInvariantChecks(vault)
    {
        IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY)).settleFundingFees();

        vault.checkGlobalMarginPositive();

        DelayedOrderStructs.Order memory order = _validateAndModifyLimitCloseOrder(tokenId_);

        _executeLeverageClose(
            ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).ownerOf(tokenId_),
            order
        );
    }

    /// @notice Function to cancel an existing order after it has expired.
    /// @dev This function can be called by anyone.
    /// @param account_ The user account which has a pending order.
    function cancelExistingOrder(address account_) external {
        DelayedOrderStructs.Order memory order = _getAnnouncedOrder(account_);

        // If there is no order in store, just return.
        if (order.orderType == DelayedOrderStructs.OrderType.None) return;

        if (block.timestamp <= order.executableAtTime + maxExecutabilityAge) revert OrderHasNotExpired();

        _cancelOrder(account_, order);
    }

    /// @notice Function to cancel an existing order by a module.
    /// @param account_ The user account which has a pending order.
    function cancelOrderByModule(address account_) external override onlyAuthorizedModule {
        _cancelOrder(account_, _getAnnouncedOrder(account_));
    }

    /////////////////////////////////////////////
    //              View Functions             //
    /////////////////////////////////////////////

    /// @notice Checks whether a user announced order has expired executability time or not
    /// @param account_ The user account which has a pending order
    /// @return expired_ True if the order has expired, false otherwise
    function hasOrderExpired(address account_) public view returns (bool expired_) {
        uint256 executableAtTime = _getAnnouncedOrder(account_).executableAtTime;

        if (executableAtTime <= 0) revert ICommonErrors.ZeroValue("executableAtTime");

        expired_ = (executableAtTime + maxExecutabilityAge >= block.timestamp) ? false : true;
    }

    /////////////////////////////////////////////
    //       Internal Execution Functions      //
    /////////////////////////////////////////////

    /// @notice User delayed deposit into the stable LP. Mints ERC20 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending deposit.
    function _executeStableDeposit(address account_, DelayedOrderStructs.Order memory order_) internal {
        DelayedOrderStructs.AnnouncedStableDeposit memory stableDeposit = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedStableDeposit)
        );

        vault.checkCollateralCap(stableDeposit.depositAmount);

        IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)).executeDeposit(
            account_,
            order_.executableAtTime,
            stableDeposit
        );

        // Collateral and fees settlement.
        {
            vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee}); // pay the keeper their fee
            vault.collateral().safeTransfer({to: address(vault), value: stableDeposit.depositAmount}); // transfer collateral to the vault
        }
    }

    /// @notice User delayed withdrawal from the stable LP.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending withdrawal.
    function _executeStableWithdraw(address account_, DelayedOrderStructs.Order memory order_) internal {
        DelayedOrderStructs.AnnouncedStableWithdraw memory stableWithdraw = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedStableWithdraw)
        );

        (uint256 amountOut, uint256 withdrawFee) = IStableModule(
            vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)
        ).executeWithdraw(account_, order_.executableAtTime, stableWithdraw);

        uint256 totalFee = order_.keeperFee + withdrawFee;

        // Make sure there is enough margin in the position to pay the keeper fee and withdrawal fee
        if (amountOut < totalFee) revert ICommonErrors.NotEnoughMarginForFees(int256(amountOut), totalFee);

        // include the fees here to check for slippage
        amountOut -= totalFee;

        if (amountOut < stableWithdraw.minAmountOut)
            revert ICommonErrors.HighSlippage(amountOut, stableWithdraw.minAmountOut);

        uint256 protocolFee = FeeManager(address(vault)).getProtocolFee(withdrawFee);

        // Collateral and fees settlement.
        {
            vault.updateStableCollateralTotal(int256(withdrawFee - protocolFee)); // pay the withdrawal fee to stable LPs
            vault.sendCollateral({to: FeeManager(address(vault)).protocolFeeRecipient(), amount: protocolFee}); // pay the protocol fee
            vault.sendCollateral({to: msg.sender, amount: order_.keeperFee}); // pay the keeper their fee
            vault.sendCollateral({to: account_, amount: amountOut}); // transfer remaining amount to the trader
        }
    }

    /// @notice Execution of user delayed leverage open order. Mints ERC721 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageOpen(address account_, DelayedOrderStructs.Order memory order_) internal {
        DelayedOrderStructs.AnnouncedLeverageOpen memory announcedOpen = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageOpen)
        );

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(announcedOpen.tradeFee);
        uint256 adjustedTradeFee = announcedOpen.tradeFee - protocolFeePortion;

        // Check that the creation of this position doesn't exceed the global leverage cap.
        vault.checkSkewMax({
            sizeChange: announcedOpen.additionalSize,
            stableCollateralChange: int256(adjustedTradeFee)
        });

        uint256 newTokenId = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY)).executeOpen({
            account: account_,
            order: order_
        });

        // Create a limit order if the user has specified valid price thresholds.
        if (announcedOpen.stopLossPrice > 0 || announcedOpen.profitTakePrice < type(uint256).max) {
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .createLimitOrder({
                    positionOwner: account_,
                    tokenId: newTokenId,
                    stopLossPrice: announcedOpen.stopLossPrice,
                    profitTakePrice: announcedOpen.profitTakePrice
                });
        }

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Transfer the protocol fee portion of the trade fee to the protocol fee recipient.
            vault.collateral().safeTransfer({
                to: FeeManager(address(vault)).protocolFeeRecipient(),
                value: protocolFeePortion
            });

            // Transfer collateral + fees to the vault
            vault.collateral().safeTransfer({to: address(vault), value: announcedOpen.margin + adjustedTradeFee});

            // Pay the keeper their fee.
            vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee});
        }
    }

    /// @notice Execution of user delayed leverage adjust order.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageAdjust(address account_, DelayedOrderStructs.Order memory order_) internal {
        DelayedOrderStructs.AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageAdjust)
        );

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        // Check that position exists (ownerOf reverts if owner is null address)
        // There is a possibility that position was deleted by liquidation or limit order module
        leverageModule.ownerOf(leverageAdjust.tokenId);

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(leverageAdjust.tradeFee);
        uint256 adjustedTradeFee = leverageAdjust.tradeFee - protocolFeePortion;

        if (leverageAdjust.additionalSizeAdjustment > 0) {
            // Given that the size of a position is being increased, it's necessary to check that
            // it doesn't exceed the max skew limit.
            vault.checkSkewMax({
                sizeChange: uint256(leverageAdjust.additionalSizeAdjustment),
                stableCollateralChange: int256(adjustedTradeFee)
            });
        }

        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
            .resetExecutionTime(leverageAdjust.tokenId);

        leverageModule.executeAdjust(order_);

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Margin adjustment amount, trade fee and keeper fee are present in this module.
            // Send the margin and adjusted fees to the vault.
            if (leverageAdjust.marginAdjustment > 0) {
                // Transfer the protocol fee portion of the trade fee to the protocol fee recipient.
                vault.collateral().safeTransfer({
                    to: FeeManager(address(vault)).protocolFeeRecipient(),
                    value: protocolFeePortion
                });

                // Transfer collateral + fees to the vault
                vault.collateral().safeTransfer({
                    to: address(vault),
                    value: uint256(leverageAdjust.marginAdjustment) + adjustedTradeFee
                });

                // Pay the keeper their fee.
                vault.collateral().safeTransfer({to: msg.sender, value: order_.keeperFee});
            } else {
                if (leverageAdjust.marginAdjustment < 0) {
                    // We send the user that much margin they requested during announceLeverageAdjust().
                    // However their remaining margin is reduced by the fees.
                    // It is accounted in announceLeverageAdjust().
                    vault.sendCollateral({to: account_, amount: uint256(leverageAdjust.marginAdjustment * -1)});
                }

                // Send the keeper fee from the vault to the keeper.
                vault.sendCollateral({to: msg.sender, amount: order_.keeperFee});

                // Send the protocol fee portion from the vault to the protocol fee recipient.
                vault.sendCollateral({
                    to: FeeManager(address(vault)).protocolFeeRecipient(),
                    amount: protocolFeePortion
                });
            }
        }
    }

    /// @notice Execution of user delayed leverage close order. Burns ERC721 token receipt.
    /// @dev Uses the Pyth network price to execute.
    /// @param account_ The user account which has a pending order.
    function _executeLeverageClose(address account_, DelayedOrderStructs.Order memory order_) internal {
        DelayedOrderStructs.AnnouncedLeverageClose memory leverageClose = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLeverageClose)
        );

        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));

        uint256 protocolFeePortion = FeeManager(address(vault)).getProtocolFee(leverageClose.tradeFee);
        uint256 adjustedTradeFee = leverageClose.tradeFee - protocolFeePortion;

        // Check that position exists (ownerOf reverts if owner is null address)
        // There is a possibility that position was deleted by liquidation or limit order module
        leverageModule.ownerOf(leverageClose.tokenId);
        uint256 marginAfterPositionClose = leverageModule.executeClose(order_);

        // Collateral and fees settlement.
        {
            // Note: Update the stable collateral total only after trade execution by the leverage module
            // to avoid any accounting issues.
            vault.updateStableCollateralTotal(int256(adjustedTradeFee));

            // Fees are paid from the remaining position margin.
            vault.sendCollateral({to: FeeManager(address(vault)).protocolFeeRecipient(), amount: protocolFeePortion});
            vault.sendCollateral({to: msg.sender, amount: order_.keeperFee});

            // Transfer the settled margin minus fee from the vault to the trader.
            vault.sendCollateral({
                to: account_,
                amount: marginAfterPositionClose - leverageClose.tradeFee - order_.keeperFee
            });
        }
    }

    function _cancelOrder(address account_, DelayedOrderStructs.Order memory order_) internal {
        // Delete the order tracker from storage.
        // NOTE: This is done before the transfer of ERC721 NFT to prevent reentrancy attacks.
        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)).deleteOrder(
            account_
        );

        if (order_.orderType == DelayedOrderStructs.OrderType.StableDeposit) {
            DelayedOrderStructs.AnnouncedStableDeposit memory stableDeposit = abi.decode(
                order_.orderData,
                (DelayedOrderStructs.AnnouncedStableDeposit)
            );

            // Send collateral back to trader
            vault.collateral().safeTransfer({to: account_, value: stableDeposit.depositAmount + order_.keeperFee});
        } else if (order_.orderType == DelayedOrderStructs.OrderType.StableWithdraw) {
            DelayedOrderStructs.AnnouncedStableWithdraw memory stableWithdraw = abi.decode(
                order_.orderData,
                (DelayedOrderStructs.AnnouncedStableWithdraw)
            );

            // Unlock the LP tokens belonging to this position which were locked during announcement.
            IStableModule(vault.moduleAddress(FlatcoinModuleKeys._STABLE_MODULE_KEY)).unlock({
                account: account_,
                amount: stableWithdraw.withdrawAmount
            });
        } else if (order_.orderType == DelayedOrderStructs.OrderType.LeverageOpen) {
            DelayedOrderStructs.AnnouncedLeverageOpen memory leverageOpen = abi.decode(
                order_.orderData,
                (DelayedOrderStructs.AnnouncedLeverageOpen)
            );

            // Send collateral back to trader
            vault.collateral().safeTransfer({
                to: account_,
                value: order_.keeperFee + leverageOpen.margin + leverageOpen.tradeFee
            });
        } else if (order_.orderType == DelayedOrderStructs.OrderType.LeverageAdjust) {
            DelayedOrderStructs.AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(
                order_.orderData,
                (DelayedOrderStructs.AnnouncedLeverageAdjust)
            );

            if (leverageAdjust.marginAdjustment > 0) {
                vault.collateral().safeTransfer({
                    to: account_,
                    value: uint256(leverageAdjust.marginAdjustment) + leverageAdjust.totalFee
                });
            }
        }

        emit OrderCancelled({account: account_, orderType: order_.orderType});
    }

    /// @dev This function HAS to be called before or as soon as the transaction flow enters an execute function.
    /// @param account_ The user account which has a pending order.
    /// @param executableAtTime_ The time at which the order can be executed.
    function _prepareExecutionOrder(address account_, uint256 executableAtTime_) internal {
        if (block.timestamp > executableAtTime_ + maxExecutabilityAge) revert OrderHasExpired();

        // Check that the minimum time delay is reached before execution
        if (block.timestamp < executableAtTime_) revert ICommonErrors.ExecutableTimeNotReached(executableAtTime_);

        // Delete the order tracker from storage.
        IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)).deleteOrder(
            account_
        );
    }

    /// @param tokenId_ The token ID of the leverage position.
    function _validateAndModifyLimitCloseOrder(
        uint256 tokenId_
    ) internal returns (DelayedOrderStructs.Order memory order_) {
        IOrderAnnouncementModule orderAnnouncementModule = IOrderAnnouncementModule(
            vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
        );
        order_ = orderAnnouncementModule.getLimitOrder(tokenId_);

        if (order_.orderType != DelayedOrderStructs.OrderType.LimitClose)
            revert OrderInvalid(address(uint160(tokenId_)));

        DelayedOrderStructs.AnnouncedLimitClose memory limitOrder = abi.decode(
            order_.orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        (uint256 price, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            asset: address(vault.collateral()),
            maxAge: 86_400,
            priceDiffCheck: true
        });

        // Check that the minimum time delay is reached before execution
        if (block.timestamp < order_.executableAtTime)
            revert ICommonErrors.ExecutableTimeNotReached(order_.executableAtTime);

        uint256 minFillPrice;
        if (price <= limitOrder.stopLossPrice) {
            minFillPrice = 0; // can execute below lower limit price threshold
        } else if (price >= limitOrder.profitTakePrice) {
            minFillPrice = limitOrder.profitTakePrice;
        } else {
            revert LimitOrderPriceNotInRange(price, limitOrder.stopLossPrice, limitOrder.profitTakePrice);
        }

        order_.orderData = abi.encode(
            DelayedOrderStructs.AnnouncedLeverageClose({
                tokenId: tokenId_,
                minFillPrice: minFillPrice,
                tradeFee: FeeManager(address(vault)).getTradeFee(vault.getPosition(tokenId_).additionalSize)
            })
        );

        order_.keeperFee = IKeeperFee(vault.moduleAddress(FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY)).getKeeperFee();

        // Delete the order tracker from storage.
        orderAnnouncementModule.deleteLimitOrder(tokenId_);

        // Emitting event here rather than in `executeLimitOrder` as the data is readily available.
        emit LimitOrderExecuted(
            tokenId_,
            (price <= limitOrder.stopLossPrice) ? LimitOrderExecutionType.StopLoss : LimitOrderExecutionType.ProfitTake
        );
    }

    /// @param account_ The user account which has a pending order.
    /// @return order_ The order struct.
    function _getAnnouncedOrder(address account_) private view returns (DelayedOrderStructs.Order memory order_) {
        return
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .getAnnouncedOrder(account_);
    }

    /////////////////////////////////////////////
    //              Owner Functions            //
    /////////////////////////////////////////////

    /// @notice Setter for the maximum time delayed executatibility.
    /// @dev The maximum executability timer starts after the minimum time has elapsed.
    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function setMaxExecutabilityAge(uint64 maxExecutabilityAge_) external onlyOwner {
        _setMaxExecutabilityAge(maxExecutabilityAge_);
    }

    /// @param maxExecutabilityAge_ The maximum amount of time that can expire between trade announcement and execution.
    function _setMaxExecutabilityAge(uint64 maxExecutabilityAge_) private {
        if (maxExecutabilityAge_ == 0) revert ICommonErrors.ZeroValue("maxExecutabilityAge");

        maxExecutabilityAge = maxExecutabilityAge_;
    }
}
