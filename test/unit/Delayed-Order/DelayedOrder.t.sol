// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "../../helpers/OrderHelpers.sol";

contract DelayedOrderTest is OrderHelpers, ExpectRevert {
    function test_revert_when_module_paused() public {
        vm.startPrank(admin);
        vaultProxy.pauseModule(ORDER_ANNOUNCEMENT_MODULE_KEY);
        vaultProxy.pauseModule(ORDER_EXECUTION_MODULE_KEY);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_ANNOUNCEMENT_MODULE_KEY)
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableWithdraw.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_ANNOUNCEMENT_MODULE_KEY)
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpen.selector,
                0,
                0,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_ANNOUNCEMENT_MODULE_KEY)
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageAdjust.selector,
                0,
                0,
                0,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_ANNOUNCEMENT_MODULE_KEY)
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageClose.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_ANNOUNCEMENT_MODULE_KEY)
        });

        bytes[] memory emptyByteArray;

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(
                orderExecutionModProxy.executeOrder.selector,
                admin,
                emptyByteArray,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, ORDER_EXECUTION_MODULE_KEY)
        });
    }

    function test_revert_announce_deposit_when_deposit_amount_too_small() public {
        uint256 depositAmount = 100;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);

        uint256 depositAmountUSD = (depositAmount * collateralAssetPrice) / (10 ** collateralAsset.decimals());

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                depositAmount,
                quotedAmount,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "AmountTooSmall(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.AmountTooSmall.selector,
                depositAmountUSD,
                orderAnnouncementModProxy.minDepositAmountUSD()
            )
        });
    }

    function test_revert_announce_deposit_when_slippage_is_high() public {
        uint256 depositAmount = 0.1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 minAmountOut = quotedAmount * 2; // 2x the quoted amount

        vm.startPrank(alice);

        collateralAsset.approve(address(orderAnnouncementModProxy), depositAmount + mockKeeperFee.getKeeperFee());

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                depositAmount,
                minAmountOut,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "HighSlippage(uint256,uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.HighSlippage.selector, quotedAmount, minAmountOut)
        });
    }

    function test_revert_announce_deposit_when_keeper_fee_too_small() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = 0;

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                depositAmount,
                quotedAmount,
                keeperFee
            ),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.InvalidFee.selector, keeperFee)
        });
    }

    function test_revert_announce_deposit_when_deposit_amount_not_approved() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        _expectRevertWith({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                depositAmount,
                quotedAmount,
                keeperFee
            ),
            revertMessage: "ERC20: subtraction underflow"
        });
    }

    function test_revert_announce_deposit_when_previous_order_has_not_expired() public {
        vm.startPrank(alice);

        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        collateralAsset.approve(address(orderAnnouncementModProxy), (depositAmount + keeperFee) * 2);

        orderAnnouncementModProxy.announceStableDeposit(depositAmount, quotedAmount, keeperFee);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                depositAmount,
                quotedAmount,
                keeperFee
            ),
            expectedErrorSignature: "OrderHasNotExpired()",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderHasNotExpired.selector)
        });
    }

    function test_revert_announce_withdraw_when_amount_not_enough() public {
        vm.startPrank(alice);

        uint256 withdrawAmount = 1e18;

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableWithdraw.selector,
                withdrawAmount,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "NotEnoughBalanceForWithdraw(address,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.NotEnoughBalanceForWithdraw.selector,
                alice,
                0,
                withdrawAmount
            )
        });
    }

    function test_revert_announce_withdraw_when_slippage_is_high() public {
        uint256 depositAmount = 1e18;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        uint256 minAmountOut = 1e18;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        (uint256 expectedAmountOut, ) = stableModProxy.stableWithdrawQuote(depositAmount);
        uint256 quotedAmount = expectedAmountOut - keeperFee;

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableWithdraw.selector,
                depositAmount,
                minAmountOut,
                keeperFee
            ),
            expectedErrorSignature: "HighSlippage(uint256,uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.HighSlippage.selector, quotedAmount, minAmountOut)
        });
    }

    function test_revert_announce_open_when_price_too_low() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 maxFillPrice = 900e18;

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpen.selector,
                depositAmount,
                depositAmount,
                maxFillPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "MaxFillPriceTooLow(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.MaxFillPriceTooLow.selector,
                maxFillPrice,
                currentPrice * 1e10
            )
        });
    }

    function test_revert_announce_adjust_when_price_too_low() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount * 2,
            margin: depositAmount,
            additionalSize: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 fillPrice = 900e18;

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageAdjust.selector,
                tokenId,
                depositAmount,
                depositAmount,
                fillPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "MaxFillPriceTooLow(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.MaxFillPriceTooLow.selector,
                fillPrice,
                currentPrice * 1e10
            )
        });
    }

    function test_revert_announce_adjust_when_price_too_high() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount * 2,
            margin: depositAmount,
            additionalSize: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 fillPrice = 1100e18;

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageAdjust.selector,
                tokenId,
                0,
                -0.1e18,
                fillPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "MinFillPriceTooHigh(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.MinFillPriceTooHigh.selector,
                fillPrice,
                currentPrice * 1e10
            )
        });
    }

    function test_revert_announce_close_when_caller_not_token_owner() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: depositAmount,
            additionalSize: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(bob);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageClose.selector,
                tokenId,
                currentPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(ICommonErrors.NotTokenOwner.selector, tokenId, bob)
        });
    }

    function test_revert_announce_close_when_when_price_too_high() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount * 2,
            margin: depositAmount,
            additionalSize: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 fillPrice = 1100e18;

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageClose.selector,
                tokenId,
                fillPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "MinFillPriceTooHigh(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.MinFillPriceTooHigh.selector,
                fillPrice,
                currentPrice * 1e10
            )
        });
    }

    function test_revert_execute_withdraw_when_time_not_reached() public {
        uint256 oraclePrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        announceStableWithdraw({traderAccount: alice, withdrawAmount: 1e18, keeperFeeAmount: 0});

        vm.startPrank(keeper);

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            ignoreErrorArguments: true,
            value: 1
        });
    }

    function test_revert_execute_withdraw_when_order_has_expired() public {
        uint256 oraclePrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        announceStableWithdraw({traderAccount: alice, withdrawAmount: 1e18, keeperFeeAmount: 0});

        skip(5 minutes);

        vm.startPrank(keeper);

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "OrderHasExpired()",
            ignoreErrorArguments: true,
            value: 1
        });
    }

    // Since all the orders are executed by calling the same function, we only need to test one of them.
    function test_revert_execute_order_when_already_executed() public {
        uint256 oraclePrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(keeper);

        bytes[] memory priceUpdateData = getPriceUpdateData(oraclePrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "OrderInvalid(address)",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderInvalid.selector, alice),
            value: 1
        });
    }

    function test_revert_announce_orders_when_global_margin_negative() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit1 = 25e18;
        uint256 stableDeposit2 = 25e18;
        uint256 margin = 6e18;
        uint256 size = 60e18;

        setCollateralPrice(collateralPrice);

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit1,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: stableDeposit2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Skipping arbitrary number of days in order to replicate margin drain
        // due to funding fee settlements.
        skip(8 days);

        setCollateralPrice(collateralPrice);

        controllerModProxy.settleFundingFees();

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDeposit.selector,
                5e18,
                stableModProxy.stableDepositQuote(5e18),
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            ignoreErrorArguments: true
        });

        (uint256 expectedAmountOut, ) = stableModProxy.stableWithdrawQuote(5e18);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableWithdraw.selector,
                5e18,
                expectedAmountOut,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            ignoreErrorArguments: true
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpen.selector,
                5e18,
                5e18,
                collateralPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            ignoreErrorArguments: true
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageAdjust.selector,
                tokenId,
                5e18,
                5e18,
                collateralPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            ignoreErrorArguments: true
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageClose.selector,
                tokenId,
                collateralPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            ignoreErrorArguments: true
        });
    }

    function test_revert_executabilityAgeSetters_when_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.setMinExecutabilityAge.selector, 1),
            expectedErrorSignature: "OnlyOwner(address)",
            ignoreErrorArguments: true
        });

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.setMaxExecutabilityAge.selector, 1),
            expectedErrorSignature: "OnlyOwner(address)",
            ignoreErrorArguments: true
        });
    }

    function test_revert_when_executability_age_is_wrong() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.setMinExecutabilityAge.selector, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "minExecutabilityAge")
        });

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.setMaxExecutabilityAge.selector, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "maxExecutabilityAge")
        });
    }

    // This test is a PoC for the audit issue <https://github.com/sherlock-audit/2024-12-flat-money-v1-1-update-judging/issues/105>.
    // This test checks that the last position in the system can be closed successfully.
    // The bug found was that, due to rounding errors in the system, the last position could not be closed.
    function test_exit_of_last_position() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 50e18;

        setCollateralPrice(collateralPrice);
        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        address[9] memory adrs;
        uint256 n = 4;
        uint256 size1 = 50.1e18;
        uint256 size2 = 1.7e18;

        adrs[1] = makeAddr("trader1");
        adrs[2] = makeAddr("trader2");
        adrs[3] = makeAddr("trader3");
        adrs[4] = makeAddr("trader4");
        adrs[5] = makeAddr("trader5");

        for (uint256 i = 1; i <= n; i++) {
            vm.startPrank(admin);
            collateralAsset.transfer(adrs[i], 100e18);
        }
        for (uint256 i = 1; i <= n; i++) {
            announceOpenLeverage(adrs[i], i == 1 ? size1 : size2, i == 1 ? size1 : size2, 0);
        }
        skip(10); // must reach minimum executability time

        uint256[9] memory tokenIds;
        for (uint256 i = 1; i <= n; i++) {
            tokenIds[i] = executeOpenLeverage(keeper, adrs[i], collateralPrice);
        }

        skip(18);
        setCollateralPrice(collateralPrice);

        for (uint256 i = n; i >= 1; i--) {
            announceCloseLeverage(adrs[i], tokenIds[i], 0);
        }
        skip(10); // must reach minimum executability time

        for (uint256 i = n; i >= 1; i--) {
            executeCloseLeverage(keeper, adrs[i], collateralPrice);
        }
    }
}
