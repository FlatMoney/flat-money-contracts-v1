// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import "./Setup.sol";

import "forge-std/Test.sol";
import "forge-std/console2.sol";

abstract contract OrderHelpers is Setup {
    /********************************************
     *             Helper Functions             *
     ********************************************/
    struct InitialPositionDetails {
        uint256 margin;
        uint256 additionalSize;
    }

    struct InitialDepositDetails {
        uint256 depositAmount;
    }

    struct AnnounceAdjustTestData {
        uint256 traderCollateralAssetBalanceBefore;
        uint256 traderNftBalanceBefore;
        uint256 orderExecutionModBalanceBefore;
        uint256 stableCollateralPerShareBefore;
        bool marginIncrease;
        uint256 totalEthRequired;
    }

    struct VerifyLeverageData {
        uint256 nftTotalSupply;
        uint256 traderCollateralAssetBalance;
        uint256 feeRecipientBalance;
        uint256 traderNftBalance;
        uint256 contractNftBalance;
        uint256 keeperBalance;
        uint256 stableCollateralPerShare;
        LeverageModuleStructs.PositionSummary positionSummary;
        uint256 oraclePrice;
        LeverageModuleStructs.Position position;
    }

    struct LeverageOpenData {
        address traderAccount;
        address receiver;
        uint256 margin;
        uint256 additionalSize;
        uint256 stopLossPrice;
        uint256 profitTakePrice;
        uint256 keeperFeeAmount;
    }

    // *** Announced stable orders ***

    function announceAndExecuteDeposit(
        address traderAccount,
        address keeperAccount,
        uint256 depositAmount,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual {
        announceAndExecuteDeposit(traderAccount, keeperAccount, depositAmount, oraclePrice, 0, keeperFeeAmount);
    }

    function announceAndExecuteDeposit(
        address traderAccount,
        address keeperAccount,
        uint256 depositAmount,
        uint256 collateralPrice,
        uint256 marketPrice,
        uint256 keeperFeeAmount
    ) public virtual {
        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();

        announceStableDeposit(traderAccount, depositAmount, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        executeStableDepositOracles(keeperAccount, traderAccount, collateralPrice, marketPrice);
    }

    function announceAndExecuteDepositFor(
        address traderAccount,
        address receiver,
        address keeperAccount,
        uint256 depositAmount,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual {
        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();

        announceStableDepositFor(traderAccount, receiver, depositAmount, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        executeStableDeposit(keeperAccount, receiver, oraclePrice);
    }

    function announceAndExecuteWithdraw(
        address traderAccount,
        address keeperAccount,
        uint256 withdrawAmount,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual {
        announceAndExecuteWithdraw(traderAccount, keeperAccount, withdrawAmount, oraclePrice, 0, keeperFeeAmount);
    }

    function announceAndExecuteWithdraw(
        address traderAccount,
        address keeperAccount,
        uint256 withdrawAmount,
        uint256 collateralPrice,
        uint256 marketPrice,
        uint256 keeperFeeAmount
    ) public virtual {
        announceStableWithdraw(traderAccount, withdrawAmount, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        executeStableWithdrawOracles(keeperAccount, traderAccount, collateralPrice, marketPrice);
    }

    function announceStableDeposit(
        address traderAccount,
        uint256 depositAmount,
        uint256 keeperFeeAmount
    ) public virtual {
        announceStableDepositFor(traderAccount, traderAccount, depositAmount, keeperFeeAmount);
    }

    function announceStableDepositFor(
        address traderAccount,
        address receiver,
        uint256 depositAmount,
        uint256 keeperFeeAmount
    ) public virtual {
        vm.startPrank(traderAccount);
        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();
        uint256 traderCollateralAssetBalance = collateralAsset.balanceOf(traderAccount);
        uint256 receiverStableBalance = stableModProxy.balanceOf(receiver);
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();
        uint256 minAmountOut = stableModProxy.stableDepositQuote(depositAmount);
        // 1% slippage to account for any funding rate effect between announce and execute
        minAmountOut = (minAmountOut * 0.99e18) / 1e18;

        // Approve collateralAsset
        collateralAsset.approve(address(orderAnnouncementModProxy), depositAmount + keeperFeeAmount);

        // Announce the order
        if (traderAccount == receiver) {
            IOrderAnnouncementModule(vaultProxy.moduleAddress(ORDER_ANNOUNCEMENT_MODULE_KEY)).announceStableDeposit({
                depositAmount: depositAmount,
                minAmountOut: minAmountOut,
                keeperFee: keeperFeeAmount
            });
        } else {
            IOrderAnnouncementModule(vaultProxy.moduleAddress(ORDER_ANNOUNCEMENT_MODULE_KEY)).announceStableDepositFor({
                depositAmount: depositAmount,
                minAmountOut: minAmountOut,
                keeperFee: keeperFeeAmount,
                receiver: receiver
            });
        }

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(receiver);

        {
            DelayedOrderStructs.AnnouncedStableDeposit memory stableDeposit = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedStableDeposit)
            );
            assertEq(stableDeposit.depositAmount, depositAmount, "Incorrect deposit order amount");
            assertEq(stableDeposit.minAmountOut, minAmountOut, "Incorrect deposit order minimum amount out");
        }
        assertEq(
            collateralAsset.balanceOf(traderAccount),
            traderCollateralAssetBalance - depositAmount - keeperFeeAmount,
            "Incorrect trader collateralAsset balance after announce"
        );
        assertEq(receiverStableBalance, stableModProxy.balanceOf(receiver), "No LP tokens should have been minted yet");
        assertApproxEqAbs(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            1e6, // rounding error only
            "stableCollateralPerShare changed after announce"
        );
        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");
        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.StableDeposit), "Order doesn't exist");
        vm.stopPrank();
    }

    function announceStableWithdraw(
        address traderAccount,
        uint256 withdrawAmount,
        uint256 keeperFeeAmount
    ) public virtual {
        vm.startPrank(traderAccount);
        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();
        uint256 vaultEthBalance = collateralAsset.balanceOf(address(vaultProxy));
        uint256 traderCollateralAssetBalance = collateralAsset.balanceOf(traderAccount);
        uint256 traderStableBalance = stableModProxy.balanceOf(traderAccount);
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();
        uint256 minAmountOut;

        {
            (uint256 withdrawalAmount, ) = stableModProxy.stableWithdrawQuote(withdrawAmount);

            if (withdrawalAmount > keeperFeeAmount) {
                minAmountOut = withdrawalAmount - keeperFeeAmount;
            } else {
                revert("OrderHelpers: Withdrawal amount is less than keeper fee");
            }
        }

        // 1% slippage to account for any funding rate effect between announce and execute
        minAmountOut = (minAmountOut * 0.99e18) / 1e18;

        // Announce the order
        IOrderAnnouncementModule(vaultProxy.moduleAddress(ORDER_ANNOUNCEMENT_MODULE_KEY)).announceStableWithdraw({
            withdrawAmount: withdrawAmount,
            minAmountOut: minAmountOut,
            keeperFee: keeperFeeAmount
        });
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);

        {
            DelayedOrderStructs.AnnouncedStableWithdraw memory stableWithdraw = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedStableWithdraw)
            );
            assertEq(stableWithdraw.withdrawAmount, withdrawAmount, "Incorrect withdraw order amount");
            assertEq(stableWithdraw.minAmountOut, minAmountOut, "Incorrect withdraw order minimum amount out");
        }
        assertEq(
            stableModProxy.balanceOf(traderAccount),
            traderStableBalance,
            "LP tokens should not have been deducted from the trader's balance yet"
        );
        assertEq(
            collateralAsset.balanceOf(traderAccount),
            traderCollateralAssetBalance,
            "Trader collateralAsset balance should not have changed yet"
        );
        assertEq(
            stableModProxy.balanceOf(address(orderExecutionModProxy)),
            0,
            "Delayed Order LP balance shouldn't have changed"
        );
        assertEq(stableModProxy.getLockedAmount(traderAccount), withdrawAmount, "Stable LP not locked on announce");
        assertEq(
            traderCollateralAssetBalance,
            collateralAsset.balanceOf(traderAccount),
            "Collateral balance changed for trader on announce"
        ); // no collateral change for the trader
        assertApproxEqAbs(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            1e6, // rounding error only
            "stableCollateralPerShare changed"
        );
        assertEq(
            vaultEthBalance,
            collateralAsset.balanceOf(address(vaultProxy)),
            "Vault collateralAsset balance changed on announce"
        );
        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");
        assertEq(
            uint256(order.orderType),
            uint256(DelayedOrderStructs.OrderType.StableWithdraw),
            "Order doesn't exist"
        );

        vm.stopPrank();
    }

    function executeStableDeposit(address keeperAccount, address traderAccount, uint256 oraclePrice) public virtual {
        executeStableDepositOracles(keeperAccount, traderAccount, oraclePrice, 0);
    }

    function executeStableDepositOracles(
        address keeperAccount,
        address traderAccount,
        uint256 collateralPrice,
        uint256 marketPrice
    ) public virtual {
        // Execute the user's pending deposit
        uint256 lpTotalSupply = stableModProxy.totalSupply();
        uint256 traderStableBalance = stableModProxy.balanceOf(traderAccount);
        uint256 keeperBalanceBefore = collateralAsset.balanceOf(keeperAccount);

        uint256 stableCollateralPerShareBefore = uint256(_getStableCollateralPerShare(collateralPrice * 1e10));

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedStableDeposit memory stableDeposit = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedStableDeposit)
        );
        uint256 depositAmount = stableDeposit.depositAmount;

        vm.startPrank(keeperAccount);

        {
            PythPrice[] memory prices = new PythPrice[](2);

            if (collateralPrice > 0 && marketPrice > 0) {
                prices[0] = PythPrice({price: collateralPrice, priceId: collateralPythId});
                prices[1] = PythPrice({price: marketPrice, priceId: collateralPythId});
            } else {
                if (collateralPrice == 0) {
                    prices[0] = PythPrice({price: marketPrice, priceId: collateralPythId});
                }
                if (marketPrice == 0) {
                    prices[0] = PythPrice({price: collateralPrice, priceId: collateralPythId});
                }
                assembly {
                    mstore(prices, sub(mload(prices), 1)) // reduce length by 1
                }
            }

            bytes[] memory priceUpdateData = getPriceUpdateDataMultiple(prices);

            orderExecutionModProxy.executeOrder{value: 2}(traderAccount, priceUpdateData);
        }

        uint256 expectedLiquidityMinted = stableModProxy.stableDepositQuote(depositAmount);

        assertEq(
            keeperBalanceBefore + order.keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "Incorrect amount sent to keeper after deposit execution"
        );

        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");

        assertApproxEqAbs(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            1e6, // rounding error only
            "stableCollateralPerShare changed after deposit execution"
        );
        assertEq(
            stableModProxy.balanceOf(traderAccount),
            traderStableBalance + expectedLiquidityMinted,
            "Incorrect deposit tokens minted to trader after deposit execution"
        );
        assertEq(
            stableModProxy.totalSupply(),
            lpTotalSupply + expectedLiquidityMinted,
            "incorrect LP total supply after deposit execution"
        );

        vm.stopPrank();
    }

    function executeStableWithdraw(address keeperAccount, address traderAccount, uint256 oraclePrice) public virtual {
        executeStableWithdrawOracles(keeperAccount, traderAccount, oraclePrice, 0);
    }

    function executeStableWithdrawOracles(
        address keeperAccount,
        address traderAccount,
        uint256 collateralPrice,
        uint256 marketPrice
    ) public virtual {
        uint256 lpTotalSupply = stableModProxy.totalSupply();
        uint256 keeperBalanceBefore = collateralAsset.balanceOf(keeperAccount);

        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedStableWithdraw memory stableWithdraw = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedStableWithdraw)
        );
        uint256 withdrawAmount = stableWithdraw.withdrawAmount;
        uint256 traderCollateralBalanceBefore = collateralAsset.balanceOf(traderAccount);
        uint256 traderLPBalanceBefore = stableModProxy.balanceOf(traderAccount);

        // Execute the user's pending withdrawal
        {
            vm.startPrank(keeperAccount);
            {
                PythPrice[] memory prices = new PythPrice[](2);

                if (marketPrice > 0) {
                    prices[0] = PythPrice({price: collateralPrice, priceId: collateralPythId});
                    prices[1] = PythPrice({price: marketPrice, priceId: collateralPythId});
                } else {
                    prices[0] = PythPrice({price: collateralPrice, priceId: collateralPythId});
                    assembly {
                        mstore(prices, sub(mload(prices), 1)) // reduce length by 1
                    }
                }
                bytes[] memory priceUpdateData = getPriceUpdateDataMultiple(prices);

                orderExecutionModProxy.executeOrder{value: 2}(traderAccount, priceUpdateData);
            }

            uint256 expectedAmountOut = (withdrawAmount * stableCollateralPerShareBefore) /
                (10 ** stableModProxy.decimals());

            uint256 withdrawFee;
            if (stableModProxy.totalSupply() > 0) {
                // don't apply the withdrawal fee on the last withdrawal
                withdrawFee = FeeManager(address(vaultProxy)).getWithdrawalFee(expectedAmountOut);
            }

            uint256 traderCollateralBalanceAfter = collateralAsset.balanceOf(traderAccount);

            assertEq(
                expectedAmountOut - order.keeperFee - withdrawFee,
                traderCollateralBalanceAfter - traderCollateralBalanceBefore,
                "incorrect collateral tokens transferred to trader after execute"
            );
        }

        if (stableModProxy.totalSupply() > 0) {
            assertLe(
                stableCollateralPerShareBefore,
                stableModProxy.stableCollateralPerShare(), // can be higher if withdraw fees are enabled
                "stableCollateralPerShare changed after execute"
            );
        }

        assertEq(stableModProxy.getLockedAmount(traderAccount), 0, "Stable LP not unlocked after execute");
        assertEq(
            stableModProxy.balanceOf(traderAccount),
            traderLPBalanceBefore - withdrawAmount,
            "Stable LP not deducted from trader after execute"
        );
        assertEq(
            stableModProxy.balanceOf(address(orderExecutionModProxy)),
            0,
            "Stable LP shouldn't be transferred to delayed order"
        );
        assertEq(
            keeperBalanceBefore + order.keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "invalid keeper fee transfer after execute"
        );
        assertEq(
            stableModProxy.balanceOf(address(orderExecutionModProxy)),
            0,
            "not all LP tokens are out of OrderExecution contract after execute"
        );
        assertEq(
            lpTotalSupply,
            stableModProxy.totalSupply() + withdrawAmount,
            "incorrect LP total supply after execute"
        );
        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");

        vm.stopPrank();
    }

    // *** Announced leverage orders ***

    function announceAndExecuteLeverageOpen(
        address traderAccount,
        address keeperAccount,
        uint256 margin,
        uint256 additionalSize,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual returns (uint256 tokenId) {
        announceOpenLeverage(traderAccount, margin, additionalSize, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        int256 fundingRateBefore = controllerModProxy.currentFundingRate();

        tokenId = executeOpenLeverage(keeperAccount, traderAccount, oraclePrice);

        assertEq(
            controllerModProxy.currentFundingRate(),
            fundingRateBefore,
            "Funding rate should not change immediately after opening position"
        );
    }

    function announceAndExecuteLeverageOpenWithLimits(
        address traderAccount,
        address keeperAccount,
        uint256 margin,
        uint256 additionalSize,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual returns (uint256 tokenId) {
        announceOpenLeverageWithLimits(
            traderAccount,
            margin,
            additionalSize,
            stopLossPrice,
            profitTakePrice,
            keeperFeeAmount
        );

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        int256 fundingRateBefore = controllerModProxy.currentFundingRate();

        tokenId = executeOpenLeverage(keeperAccount, traderAccount, oraclePrice);

        assertEq(
            controllerModProxy.currentFundingRate(),
            fundingRateBefore,
            "Funding rate should not change immediately after opening position"
        );
    }

    // function announceAndExecuteLeverageOpenWithLimits(
    //     address traderAccount,
    //     address keeperAccount,
    //     uint256 margin,
    //     uint256 additionalSize,
    //     uint256 stopLossPrice,
    //     uint256 profitTakePrice,
    //     uint256 oraclePrice,
    //     uint256 keeperFeeAmount
    // ) public virtual returns (uint256 tokenId) {
    //     announceOpenLeverageWithLimits(
    //         traderAccount,
    //         margin,
    //         additionalSize,
    //         stopLossPrice,
    //         profitTakePrice,
    //         keeperFeeAmount
    //     );

    //     skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

    //     int256 fundingRateBefore = controllerModProxy.currentFundingRate();

    //     tokenId = executeOpenLeverage(keeperAccount, traderAccount, oraclePrice);

    //     assertEq(
    //         controllerModProxy.currentFundingRate(),
    //         fundingRateBefore,
    //         "Funding rate should not change immediately after opening position"
    //     );
    // }

    function announceAndExecuteLeverageOpenFor(
        address traderAccount,
        address receiver,
        address keeperAccount,
        uint256 margin,
        uint256 additionalSize,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual returns (uint256 tokenId) {
        announceOpenLeverageFor(
            traderAccount,
            receiver,
            margin,
            additionalSize,
            stopLossPrice,
            profitTakePrice,
            keeperFeeAmount
        );

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        int256 fundingRateBefore = controllerModProxy.currentFundingRate();

        tokenId = executeOpenLeverage(keeperAccount, receiver, oraclePrice);

        assertEq(
            controllerModProxy.currentFundingRate(),
            fundingRateBefore,
            "Funding rate should not change immediately after opening position"
        );
    }

    function announceAndExecuteLeverageAdjust(
        uint256 tokenId,
        address traderAccount,
        address keeperAccount,
        int256 marginAdjustment,
        int256 additionalSizeAdjustment,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public returns (uint256 tradeFee) {
        announceAdjustLeverage(traderAccount, tokenId, marginAdjustment, additionalSizeAdjustment, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        int256 fundingRateBefore = controllerModProxy.currentFundingRate();

        tradeFee = executeAdjustLeverage(keeperAccount, traderAccount, oraclePrice);

        assertEq(
            controllerModProxy.currentFundingRate(),
            fundingRateBefore,
            "Funding rate should not change immediately after adjustment"
        );
    }

    function announceAndExecuteLeverageClose(
        uint256 tokenId,
        address traderAccount,
        address keeperAccount,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual {
        announceCloseLeverage(traderAccount, tokenId, keeperFeeAmount);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        int256 fundingRateBefore = controllerModProxy.currentFundingRate();

        executeCloseLeverage(keeperAccount, traderAccount, oraclePrice);

        assertEq(
            fundingRateBefore,
            controllerModProxy.currentFundingRate(),
            "Funding rate should not change immediately after close"
        );
    }

    function announceOpenLeverage(
        address traderAccount,
        uint256 margin,
        uint256 additionalSize,
        uint256 keeperFeeAmount
    ) public virtual {
        vm.startPrank(traderAccount);

        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();

        // Approve collateralAsset
        collateralAsset.approve(
            address(orderAnnouncementModProxy),
            margin + keeperFeeAmount + FeeManager(address(vaultProxy)).getTradeFee(additionalSize)
        );

        // Announce the order
        uint256 maxFillPrice = collateralAssetPrice;
        orderAnnouncementModProxy.announceLeverageOpen(
            margin,
            additionalSize,
            maxFillPrice + 100, // add some slippage
            keeperFeeAmount
        );
    }

    function announceOpenLeverageWithLimits(
        address traderAccount,
        uint256 margin,
        uint256 additionalSize,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFeeAmount
    ) internal {
        vm.startPrank(traderAccount);

        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();

        // Approve collateralAsset
        uint256 tradeFee = (vaultProxy.leverageTradingFee() * additionalSize) / 1e18;
        collateralAsset.approve(address(orderAnnouncementModProxy), margin + keeperFeeAmount + tradeFee);

        // Announce the order
        uint256 maxFillPrice = collateralAssetPrice;
        orderAnnouncementModProxy.announceLeverageOpenWithLimits(
            margin,
            additionalSize,
            maxFillPrice + 100, // add some slippage
            stopLossPrice,
            profitTakePrice,
            keeperFeeAmount
        );
    }

    function announceOpenLeverageFor(
        address traderAccount,
        address receiver,
        uint256 margin,
        uint256 additionalSize,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFeeAmount
    ) public virtual {
        LeverageOpenData memory data = LeverageOpenData({
            traderAccount: traderAccount,
            receiver: receiver,
            margin: margin,
            additionalSize: additionalSize,
            stopLossPrice: stopLossPrice,
            profitTakePrice: profitTakePrice,
            keeperFeeAmount: keeperFeeAmount
        });

        announceOpenLeverageFor(data);
    }

    function announceOpenLeverageFor(LeverageOpenData memory data) public virtual {
        vm.startPrank(data.traderAccount);
        data.keeperFeeAmount = data.keeperFeeAmount > 0 ? data.keeperFeeAmount : mockKeeperFee.getKeeperFee();
        uint256 traderCollateralAssetBalance = collateralAsset.balanceOf(data.traderAccount);
        uint256 traderNftBalance = leverageModProxy.balanceOf(data.traderAccount);
        uint256 feeRecipientBalanceBefore = collateralAsset.balanceOf(feeRecipient);
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        // Approve collateralAsset
        uint256 tradeFee = (FeeManager(address(vaultProxy)).leverageTradingFee() * data.additionalSize) / 1e18;
        collateralAsset.approve(address(orderAnnouncementModProxy), data.margin + data.keeperFeeAmount + tradeFee);

        // Announce the order
        uint256 maxFillPrice = collateralAssetPrice;
        orderAnnouncementModProxy.announceLeverageOpenFor(
            data.margin,
            data.additionalSize,
            maxFillPrice + 100, // add some slippage
            data.stopLossPrice,
            data.profitTakePrice,
            data.keeperFeeAmount,
            data.receiver
        );
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(data.receiver);
        {
            DelayedOrderStructs.AnnouncedLeverageOpen memory leverageOpen = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedLeverageOpen)
            );
            assertEq(leverageOpen.margin, data.margin, "Announce open order margin incorrect");
            assertEq(leverageOpen.additionalSize, data.additionalSize, "Announce open order additionalSize incorrect");
            assertEq(leverageOpen.maxFillPrice - 100, maxFillPrice, "Announce open order invalid maximum fill price");
        }

        assertEq(order.keeperFee, data.keeperFeeAmount, "Incorrect keeper fee in order");
        assertGt(order.executableAtTime, block.timestamp, "Order executability should be after current time");
        assertEq(
            collateralAsset.balanceOf(data.traderAccount),
            traderCollateralAssetBalance - data.margin - data.keeperFeeAmount - tradeFee,
            "Trader collateralAsset balance incorrect after announcement"
        );
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            feeRecipientBalanceBefore,
            "Fee recipient balance shouldn't change"
        );
        assertEq(
            traderNftBalance,
            leverageModProxy.balanceOf(data.traderAccount),
            "Trader should not have NFT minted after announcement"
        ); // no tokens minted yet
        assertEq(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            "Stable collateral per share has not remained the same after announce"
        );
        assertGt(order.keeperFee, 0, "Keeper fee should not be 0");
        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.LeverageOpen), "Order doesn't exist");
        vm.stopPrank();
    }

    function announceAdjustLeverage(
        address traderAccount,
        uint256 tokenId,
        int256 marginAdjustment,
        int256 additionalSizeAdjustment,
        uint256 keeperFeeAmount
    ) public {
        vm.startPrank(traderAccount);

        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();
        bool sizeIncrease = additionalSizeAdjustment >= 0;

        AnnounceAdjustTestData memory testData = AnnounceAdjustTestData({
            traderCollateralAssetBalanceBefore: collateralAsset.balanceOf(traderAccount),
            traderNftBalanceBefore: leverageModProxy.balanceOf(traderAccount),
            orderExecutionModBalanceBefore: collateralAsset.balanceOf(address(orderExecutionModProxy)),
            stableCollateralPerShareBefore: stableModProxy.stableCollateralPerShare(),
            marginIncrease: marginAdjustment > 0,
            totalEthRequired: uint256(marginAdjustment) +
                keeperFeeAmount +
                (vaultProxy.leverageTradingFee() *
                    (sizeIncrease ? uint256(additionalSizeAdjustment) : uint256(additionalSizeAdjustment * -1))) /
                1e18 // margin + keeper fee + trade fee
        });

        if (testData.marginIncrease) {
            collateralAsset.approve(address(orderAnnouncementModProxy), testData.totalEthRequired);
        }

        uint256 modifiedFillPrice = collateralAssetPrice;
        uint256 fillPrice = sizeIncrease ? modifiedFillPrice + 100 : modifiedFillPrice - 100; // not sure why it's needed
        orderAnnouncementModProxy.announceLeverageAdjust(
            tokenId,
            marginAdjustment,
            additionalSizeAdjustment,
            fillPrice,
            keeperFeeAmount
        );

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedLeverageAdjust)
        );

        assertEq(leverageAdjust.tokenId, tokenId, "Announce adjust order invalid token ID");

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageAdjust)
        );
        leverageModProxy.safeTransferFrom(traderAccount, makeAddr("dummyAddress"), tokenId);

        assertEq(leverageAdjust.marginAdjustment, marginAdjustment, "Announce adjust order invalid margin adjustment");
        assertEq(
            leverageAdjust.additionalSizeAdjustment,
            additionalSizeAdjustment,
            "Announce adjust order invalid additional size adjustment"
        );
        assertEq(
            sizeIncrease ? leverageAdjust.fillPrice - 100 : leverageAdjust.fillPrice + 100,
            modifiedFillPrice,
            "Announce adjust order invalid fill price"
        );
        assertEq(order.keeperFee, keeperFeeAmount, "Incorrect keeper fee in announce adjust order");
        assertGt(
            order.executableAtTime,
            block.timestamp,
            "Announce adjust order executability should be after current time"
        );
        assertGt(order.keeperFee, 0, "Keeper fee should not be 0");
        assertEq(
            uint256(order.orderType),
            uint256(DelayedOrderStructs.OrderType.LeverageAdjust),
            "Order doesn't exist"
        );

        assertEq(
            testData.traderNftBalanceBefore,
            leverageModProxy.balanceOf(traderAccount),
            "Trader NFT balance incorrect after adjust announcement"
        );
        assertEq(
            testData.stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            "Stable collateral per share has not remained the same after adjust announcement"
        );

        if (testData.marginIncrease) {
            assertEq(
                testData.orderExecutionModBalanceBefore + testData.totalEthRequired,
                collateralAsset.balanceOf(address(orderExecutionModProxy)),
                "OrderExecution collateralAsset balance incorrect after adjust announcement"
            );
            assertEq(
                testData.traderCollateralAssetBalanceBefore - testData.totalEthRequired,
                collateralAsset.balanceOf(traderAccount),
                "Trader collateralAsset balance incorrect after adjust announcement"
            );
        } else {
            assertEq(
                testData.orderExecutionModBalanceBefore,
                collateralAsset.balanceOf(address(orderExecutionModProxy)),
                "OrderExecution collateralAsset balance incorrect after adjust announcement"
            );
            assertEq(
                testData.traderCollateralAssetBalanceBefore,
                collateralAsset.balanceOf(traderAccount),
                "Trader collateralAsset balance incorrect after adjust announcement"
            );
        }

        vm.stopPrank();
    }

    function announceCloseLeverage(address traderAccount, uint256 tokenId, uint256 keeperFeeAmount) public virtual {
        vm.startPrank(traderAccount);
        keeperFeeAmount = keeperFeeAmount > 0 ? keeperFeeAmount : mockKeeperFee.getKeeperFee();
        uint256 traderCollateralAssetBalanceBefore = collateralAsset.balanceOf(traderAccount);
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();
        int256 positionMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;

        uint256 minFillPrice = collateralAssetPrice;

        // Announce the order
        orderAnnouncementModProxy.announceLeverageClose(
            tokenId,
            minFillPrice - 100, // add some slippage
            keeperFeeAmount
        );
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        {
            DelayedOrderStructs.AnnouncedLeverageClose memory leverageClose = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedLeverageClose)
            );

            vm.expectRevert(
                abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageClose)
            );
            leverageModProxy.safeTransferFrom(traderAccount, makeAddr("dummyAddress"), tokenId);

            assertEq(leverageClose.tokenId, tokenId, "Announce close order invalid token ID");
            assertEq(leverageClose.minFillPrice + 100, minFillPrice, "Announce close order invalid minimum fill price");
        }

        assertEq(
            collateralAsset.balanceOf(traderAccount),
            traderCollateralAssetBalanceBefore,
            "Trader collateralAsset balance should not have changed"
        );
        assertEq(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            "Stable collateral per share has not remained the same after announce"
        );
        assertGt(positionMargin, 0, "Position margin isn't > 0 after announce");
        assertGt(order.keeperFee, 0, "Keeper fee should not be 0");
        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.LeverageClose), "Order doesn't exist");
        vm.stopPrank();
    }

    function executeOpenLeverage(
        address keeperAccount,
        address traderAccount,
        uint256 oraclePrice
    ) public virtual returns (uint256 tokenId) {
        uint256 traderNftBalanceBefore = leverageModProxy.balanceOf(traderAccount);
        uint256 keeperBalanceBefore = collateralAsset.balanceOf(keeperAccount);
        uint256 stableCollateralPerShareBefore = uint256(_getStableCollateralPerShare(oraclePrice * 1e10));

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedLeverageOpen memory leverageOpen = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedLeverageOpen)
        );

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice, collateralPythId);

        // Execute the user's pending deposit
        vm.startPrank(keeperAccount);

        orderExecutionModProxy.executeOrder{value: 1}(traderAccount, priceUpdateData);
        uint256 traderBalance = leverageModProxy.balanceOf(traderAccount);
        tokenId = leverageModProxy.tokenOfOwnerByIndex(traderAccount, traderBalance - 1);

        {
            uint256 tradingFee = (vaultProxy.leverageTradingFee() * leverageOpen.additionalSize) / 1e18;
            uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradingFee) / 1e18;
            uint256 totalSupply = stableModProxy.totalSupply();

            if (totalSupply > 0) {
                assertApproxEqAbs(
                    stableCollateralPerShareBefore +
                        (((tradingFee - protocolFee) * (10 ** stableModProxy.decimals())) / totalSupply),
                    stableModProxy.stableCollateralPerShare(), // there should be some additional value in the stable LPs from earned trading fee
                    1e6, // rounding error only
                    "stableCollateralPerShare incorrect after trade"
                );
            }
        }

        assertEq(traderNftBalanceBefore, leverageModProxy.balanceOf(traderAccount) - 1, "Position NFT not minted");
        {
            LeverageModuleStructs.PositionSummary memory positionSummary = leverageModProxy.getPositionSummary(tokenId);
            LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);
            uint256 price = collateralAssetPrice;
            assertEq(position.averagePrice, price, "Position last price incorrect");
            assertEq(
                position.averagePrice,
                oraclePrice * 1e10, // convert to 18 decimals
                "Position last price incorrect"
            );
            assertEq(position.marginDeposited, leverageOpen.margin, "Position margin deposited incorrect");
            assertEq(position.additionalSize, leverageOpen.additionalSize, "Position additional size incorrect");
            assertEq(
                position.entryCumulativeFunding,
                controllerModProxy.cumulativeFundingRate(),
                "Position entry cumulative funding rate incorrect"
            );
            assertEq(
                uint256(positionSummary.marginAfterSettlement),
                leverageOpen.margin,
                "Position margin after settlement incorrect"
            );
            assertEq(uint256(positionSummary.profitLoss), 0, "Position PnL should be 0");
            assertEq(uint256(positionSummary.accruedFunding), 0, "Position accrued funding should be 0");
        }
        {
            LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);
            assertEq(
                position.averagePrice,
                oraclePrice * 1e10, // convert to 18 decimals
                "Position last price invalid"
            );
            assertEq(position.additionalSize, leverageOpen.additionalSize, "Position additionalSize invalid");
            assertEq(position.marginDeposited, leverageOpen.margin, "Position marginDeposited invalid");
        }
        assertEq(
            keeperBalanceBefore + order.keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "Incorrect amount sent to keeper after execution"
        );
        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");
    }

    function executeAdjustLeverage(
        address keeperAccount,
        address traderAccount,
        uint256 oraclePrice
    ) public returns (uint256 tradeFee) {
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedLeverageAdjust memory leverageAdjust = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedLeverageAdjust)
        );

        VerifyLeverageData memory before = VerifyLeverageData({
            nftTotalSupply: leverageModProxy.totalSupply(),
            traderCollateralAssetBalance: collateralAsset.balanceOf(traderAccount),
            feeRecipientBalance: collateralAsset.balanceOf(feeRecipient),
            traderNftBalance: leverageModProxy.balanceOf(traderAccount),
            contractNftBalance: leverageModProxy.balanceOf(address(orderExecutionModProxy)),
            keeperBalance: collateralAsset.balanceOf(keeperAccount),
            stableCollateralPerShare: uint256(_getStableCollateralPerShare(oraclePrice * 1e10)),
            positionSummary: leverageModProxy.getPositionSummary(leverageAdjust.tokenId),
            oraclePrice: collateralAssetPrice,
            position: vaultProxy.getPosition(leverageAdjust.tokenId)
        });

        vm.startPrank(keeperAccount);
        orderExecutionModProxy.executeOrder{value: 1}(traderAccount, getPriceUpdateData(oraclePrice));

        {
            uint256 protocolFee = (vaultProxy.protocolFeePercentage() * leverageAdjust.tradeFee) / 1e18;
            uint256 totalSupply = stableModProxy.totalSupply();

            assertApproxEqAbs(
                before.stableCollateralPerShare +
                    (((leverageAdjust.tradeFee - protocolFee) * (10 ** stableModProxy.decimals())) / totalSupply),
                stableModProxy.stableCollateralPerShare(), // there should be some additional value in the stable LPs from earned trading fee
                1e6, // rounding error only
                "stableCollateralPerShare incorrect after execute adjust"
            );
            assertEq(
                collateralAsset.balanceOf(feeRecipient),
                before.feeRecipientBalance + protocolFee,
                "Fee recipient balance incorrect"
            );
        }

        if (leverageAdjust.marginAdjustment > 0) {
            assertEq(
                before.traderCollateralAssetBalance,
                collateralAsset.balanceOf(traderAccount),
                "Trader collateral balance not same when margin adjustment > 0 after execute adjust"
            );
        } else {
            assertEq(
                before.traderCollateralAssetBalance + uint256(leverageAdjust.marginAdjustment * -1),
                collateralAsset.balanceOf(traderAccount),
                "Incorrect amount sent to trader after execute adjust"
            );
        }

        // Test transferability of NFTs after order execution.
        {
            address dummy = makeAddr("dummyAddress");

            // If a limit order exists for the `tokenId`, the NFT should not be transferable.
            if (
                orderAnnouncementModProxy.getLimitOrder(leverageAdjust.tokenId).orderType ==
                DelayedOrderStructs.OrderType.None
            ) {
                vm.startPrank(traderAccount);
                leverageModProxy.safeTransferFrom(traderAccount, dummy, leverageAdjust.tokenId);

                vm.startPrank(dummy);
                leverageModProxy.safeTransferFrom(dummy, traderAccount, leverageAdjust.tokenId);

                // Revert to the original prankster.
                vm.startPrank(keeperAccount);
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LimitClose)
                );

                leverageModProxy.safeTransferFrom(traderAccount, dummy, leverageAdjust.tokenId);
            }
        }

        assertEq(
            before.traderNftBalance,
            leverageModProxy.balanceOf(traderAccount),
            "Position NFT balance changed after execute adjust"
        );
        assertEq(
            before.nftTotalSupply,
            leverageModProxy.totalSupply(),
            "NFT Total supply didn't remain the same after adjust"
        );

        {
            LeverageModuleStructs.Position memory position = vaultProxy.getPosition(leverageAdjust.tokenId);

            if (leverageAdjust.additionalSizeAdjustment > 0) {
                assertEq(
                    int256(before.position.marginDeposited) +
                        (
                            (leverageAdjust.marginAdjustment > 0)
                                ? leverageAdjust.marginAdjustment
                                : leverageAdjust.marginAdjustment - int256(leverageAdjust.totalFee)
                        ),
                    int256(position.marginDeposited),
                    "New margin deposited should have been set as: margin deposited + margin delta"
                );
            } else {
                // TODO: Calculate new margin deposited when additional size is decreased
            }

            assertEq(
                position.additionalSize,
                uint256(int256(before.position.additionalSize) + leverageAdjust.additionalSizeAdjustment),
                "Position new additional size incorrect after adjust"
            );
            // we account fees only when withdrawing margin, as in this case they're taken from existing margin and affect marginAfterSettlement
            uint256 feesToAccount = leverageAdjust.marginAdjustment <= 0 ? leverageAdjust.totalFee : 0;
            assertApproxEqAbs(
                before.positionSummary.marginAfterSettlement + leverageAdjust.marginAdjustment - int256(feesToAccount),
                leverageModProxy.getPositionSummary(leverageAdjust.tokenId).marginAfterSettlement,
                1e6, // Rounding error only.
                "Margin after settlement should be the same before and after adjustment"
            );
        }

        assertEq(
            before.keeperBalance + order.keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "Incorrect amount sent to keeper after adjust"
        );
        assertGt(order.keeperFee, 0, "Keeper fee amount not > 0");

        tradeFee = leverageAdjust.tradeFee;

        if (leverageAdjust.additionalSizeAdjustment > 0) {
            int256 calculatedTradeFee = (int256(uint256(vaultProxy.leverageTradingFee())) *
                leverageAdjust.additionalSizeAdjustment) / 1e18;
            assertEq(int256(tradeFee), calculatedTradeFee, "Trade fee incorrect after positive size adjustment");
            assertEq(
                collateralAsset.balanceOf(feeRecipient),
                before.feeRecipientBalance + (vaultProxy.protocolFeePercentage() * tradeFee) / 1e18,
                "Fee recipient balance incorrect"
            );
        } else if (leverageAdjust.additionalSizeAdjustment < 0) {
            int256 calculatedTradeFee = (int256(uint256(vaultProxy.leverageTradingFee())) *
                leverageAdjust.additionalSizeAdjustment *
                -1) / 1e18;
            assertEq(int256(tradeFee), calculatedTradeFee, "Trade fee incorrect after positive size adjustment");
            assertEq(
                collateralAsset.balanceOf(feeRecipient),
                before.feeRecipientBalance + (vaultProxy.protocolFeePercentage() * tradeFee) / 1e18,
                "Fee recipient balance incorrect"
            );
        } else {
            assertEq(tradeFee, 0, "Trade fee not 0 after no size adjustment");
            assertEq(
                collateralAsset.balanceOf(feeRecipient),
                before.feeRecipientBalance,
                "Fee recipient balance incorrect when no size adjustment"
            );
        }
    }

    function executeCloseLeverage(
        address keeperAccount,
        address traderAccount,
        uint256 oraclePrice
    ) public virtual returns (int256 settledMargin) {
        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(traderAccount);
        DelayedOrderStructs.AnnouncedLeverageClose memory leverageClose = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedLeverageClose)
        );

        VerifyLeverageData memory before = VerifyLeverageData({
            nftTotalSupply: leverageModProxy.totalSupply(),
            traderCollateralAssetBalance: collateralAsset.balanceOf(traderAccount),
            feeRecipientBalance: collateralAsset.balanceOf(feeRecipient),
            traderNftBalance: leverageModProxy.balanceOf(traderAccount),
            contractNftBalance: leverageModProxy.balanceOf(address(orderExecutionModProxy)),
            keeperBalance: collateralAsset.balanceOf(keeperAccount),
            stableCollateralPerShare: uint256(_getStableCollateralPerShare(oraclePrice * 1e10)),
            positionSummary: leverageModProxy.getPositionSummary(leverageClose.tokenId),
            oraclePrice: collateralAssetPrice,
            position: vaultProxy.getPosition(leverageClose.tokenId)
        });

        uint256 tradeFee = (vaultProxy.leverageTradingFee() * before.position.additionalSize) / 1e18;
        uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradeFee) / 1e18;

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice);

        {
            // Execute order doesn't have any return data so we need to try and estimate the settled margin
            // in the position by the trader's collateralAsset balance before and after the transaction execution
            uint256 traderCollateralAssetBalanceBefore = collateralAsset.balanceOf(traderAccount);
            vm.startPrank(keeperAccount);
            orderExecutionModProxy.executeOrder{value: 1}(traderAccount, priceUpdateData);
            uint256 traderCollateralAssetBalanceAfter = collateralAsset.balanceOf(traderAccount);
            settledMargin =
                int256(traderCollateralAssetBalanceAfter) -
                int256(traderCollateralAssetBalanceBefore) +
                int256(order.keeperFee) +
                int(tradeFee);
        }

        {
            LeverageModuleStructs.PositionSummary memory positionSummary = leverageModProxy.getPositionSummary(
                leverageClose.tokenId
            );
            assertEq(positionSummary.profitLoss, 0, "Profit loss isn't 0 after close");
            assertEq(positionSummary.accruedFunding, 0, "Accrued funding loss isn't 0 after close");
            assertEq(positionSummary.marginAfterSettlement, 0, "Margin after settlement loss isn't 0 after close");
        }

        // more room for error with lower decimal collateral because stableCollateralPerShare is 18 decimals
        {
            uint256 errorMargin = collateralAsset.decimals() <= 8 ? 1e8 : 1e6;
            assertApproxEqAbs(
                before.stableCollateralPerShare +
                    (((tradeFee - protocolFee) * (10 ** stableModProxy.decimals())) / stableModProxy.totalSupply()),
                stableModProxy.stableCollateralPerShare(), // there should be some additional value in the stable LPs from earned trading fee
                errorMargin,
                "stableCollateralPerShare incorrect after close leverage"
            );
        }

        assertEq(
            before.traderCollateralAssetBalance,
            collateralAsset.balanceOf(traderAccount) -
                (
                    before.positionSummary.marginAfterSettlement > 0
                        ? uint256(before.positionSummary.marginAfterSettlement) - order.keeperFee - tradeFee
                        : 0
                ),
            "Trader collateralAsset balance wrong after close"
        );
        assertEq(
            before.traderNftBalance - 1,
            leverageModProxy.balanceOf(traderAccount),
            "Position NFT still assigned to the trader after burning"
        );
        assertEq(
            before.nftTotalSupply - 1,
            leverageModProxy.totalSupply(),
            "ERC721 token supply not reduced after burn"
        );
        assertEq(
            uint256(settledMargin),
            uint256(before.positionSummary.marginAfterSettlement),
            "Settled margin incorrect after close"
        );

        assertEq(
            before.keeperBalance + order.keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "Keeper collateralAsset balance wrong after close"
        );
        bool positionZero = vaultProxy.getPosition(leverageClose.tokenId).additionalSize > 0 ||
            vaultProxy.getPosition(leverageClose.tokenId).averagePrice > 0 ||
            vaultProxy.getPosition(leverageClose.tokenId).entryCumulativeFunding > 0 ||
            vaultProxy.getPosition(leverageClose.tokenId).marginDeposited > 0
            ? false
            : true;
        assertEq(positionZero, true, "Position data isn't 0 after close");
        assertEq(before.nftTotalSupply, leverageModProxy.totalSupply() + 1, "ERC721 not burned after close");
        assertGt(order.keeperFee, 0, "keeper fee amount not > 0");
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            before.feeRecipientBalance + protocolFee,
            "Fee recipient balance incorrect after close"
        );

        vm.stopPrank();
    }

    function announceAndExecuteDepositAndLeverageOpen(
        address traderAccount,
        address keeperAccount,
        uint256 depositAmount,
        uint256 margin,
        uint256 additionalSize,
        uint256 oraclePrice,
        uint256 keeperFeeAmount
    ) public virtual returns (uint256 tokenId) {
        uint256 maxFundingVelocity = controllerModProxy.maxFundingVelocity();

        // Disable funding rates.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0);

        vm.startPrank(traderAccount);

        announceAndExecuteDeposit({
            traderAccount: traderAccount,
            keeperAccount: keeperAccount,
            depositAmount: depositAmount,
            oraclePrice: oraclePrice,
            keeperFeeAmount: keeperFeeAmount
        });

        tokenId = announceAndExecuteLeverageOpen({
            traderAccount: traderAccount,
            keeperAccount: keeperAccount,
            margin: margin,
            additionalSize: additionalSize,
            oraclePrice: oraclePrice,
            keeperFeeAmount: keeperFeeAmount
        });

        // Enable funding rates.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(maxFundingVelocity);

        vm.stopPrank();
    }

    // *** Limit orders ***

    function announceAndExecuteLimitClose(
        uint256 tokenId,
        address traderAccount,
        address keeperAccount,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 oraclePrice
    ) public virtual {
        uint256[] memory balances = new uint256[](3);
        balances[0] = collateralAsset.balanceOf(keeperAccount);
        balances[1] = collateralAsset.balanceOf(traderAccount);
        balances[2] = collateralAsset.balanceOf(feeRecipient);

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: stopLossPrice,
            profitTakePrice_: profitTakePrice
        });

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getLimitOrder(tokenId);
        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.LimitClose));
        assertEq(order.keeperFee, 0, "Limit order keeper fee not 0"); // limit orders have no keeper fee
        assertEq(order.executableAtTime, block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        {
            DelayedOrderStructs.AnnouncedLimitClose memory limitClose = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedLimitClose)
            );
            assertEq(limitClose.stopLossPrice, stopLossPrice);
            assertEq(limitClose.profitTakePrice, profitTakePrice);
            assertEq(limitClose.tokenId, tokenId);
        }

        setCollateralPrice(oraclePrice);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        uint256 tradeFee;
        {
            LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);
            tradeFee = (vaultProxy.leverageTradingFee() * position.additionalSize) / 1e18;
        }

        assertGt(settledMargin, 0, "Settled margin should be > 0 before limit close execution");

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice);

        vm.startPrank(keeper);

        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            balances[0] + keeperFee,
            collateralAsset.balanceOf(keeperAccount),
            "Incorrect amount sent to keeper after limit close execution"
        );
        assertGt(
            collateralAsset.balanceOf(traderAccount),
            balances[1],
            "Trader collateralAsset balance should have increased after limit close execution"
        );
        assertEq(
            balances[1] + uint256(settledMargin) - tradeFee - keeperFee,
            collateralAsset.balanceOf(traderAccount),
            "Trader collateralAsset balance incorrect after limit close execution"
        );
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            balances[2] + (vaultProxy.protocolFeePercentage() * tradeFee) / 1e18,
            "Fee recipient balance incorrect after limit close execution"
        );

        order = orderAnnouncementModProxy.getLimitOrder(tokenId);

        assertEq(uint256(order.orderType), 0);
        assertEq(order.keeperFee, 0);
        assertEq(order.executableAtTime, 0);
    }

    /// @dev `dollarAmount` is with 18 decimals. So $10 is equal to 10e18.
    /// @param toAsset Either market or collateral asset.
    /// @return The amount of `toAsset` that can be bought with `dollarAmount`.
    function getQuoteFromDollarAmount(uint256 dollarAmount, MockERC20 toAsset) public view returns (uint256) {
        return (dollarAmount * (10 ** toAsset.decimals())) / collateralAssetPrice;
    }

    function _getStableCollateralPerShare(uint256 price) private view returns (uint256 collateralPerShare) {
        uint256 totalSupply = stableModProxy.totalSupply();

        if (totalSupply > 0) {
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary(price);

            int256 netTotal = marketSummary.profitLossTotalByLongs + marketSummary.accruedFundingTotalByLongs;

            // The flatcoin LPs are the counterparty to the leverage traders.
            // So when the traders win, the flatcoin LPs lose and vice versa.
            // Therefore we subtract the leverage trader profits and add the losses
            int256 totalAfterSettlement = int256(vaultProxy.stableCollateralTotal()) - netTotal;
            uint256 stableCollateralBalance;

            if (totalAfterSettlement < 0) {
                stableCollateralBalance = 0;
            } else {
                stableCollateralBalance = uint256(totalAfterSettlement);
            }

            collateralPerShare = (stableCollateralBalance * (10 ** stableModProxy.decimals())) / totalSupply;
        } else {
            // no shares have been minted yet
            collateralPerShare = 1e36 / price;
        }
    }
}
