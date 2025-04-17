// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract AnnounceForTest is OrderHelpers, ExpectRevert {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(admin);

        // Add all accounts as authorized callers.
        // This allows them to make certain announcements on behalf of other addresses.
        for (uint8 i; i < accounts.length; ++i) {
            orderAnnouncementModProxy.addAuthorizedCaller(accounts[i]);
        }
    }

    function test_announceFor_deposit_open_close() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;
        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 bobLPQuote = stableModProxy.stableDepositQuote(depositAmount);

        vm.startPrank(alice);

        announceAndExecuteDepositFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenFor({
            traderAccount: alice,
            receiver: carol,
            keeperAccount: keeper,
            margin: depositAmount,
            additionalSize: depositAmount,
            stopLossPrice: 0,
            profitTakePrice: type(uint256).max,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            aliceBalanceBefore - collateralAsset.balanceOf(alice),
            (depositAmount + mockKeeperFee.getKeeperFee()) * 2,
            "Alice should have the correct collateralAsset balance after leverage open"
        );
        assertEq(leverageModProxy.balanceOf(alice), 0, "Alice should have no leverage token balance");
        assertEq(stableModProxy.balanceOf(alice), 0, "Alice should have no LP balance");
        assertEq(stableModProxy.balanceOf(bob), bobLPQuote, "Bob's LP token balance incorrect");
        assertEq(stableModProxy.balanceOf(carol), 0, "Carol should have no LP balance");

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: carol,
            keeperAccount: keeper,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(bob),
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        assertEq(collateralAsset.balanceOf(address(vaultProxy)), 0, "Should be no balance remaining in contracts");
    }

    function test_announceFor_deposit_open_multiple() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        uint256 bobLPQuote = stableModProxy.stableDepositQuote(depositAmount);
        uint256 carolLPQuote = stableModProxy.stableDepositQuote(depositAmount * 2);

        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        announceStableDeposit({traderAccount: bob, depositAmount: depositAmount, keeperFeeAmount: 0});
        announceStableDepositFor({
            traderAccount: bob,
            receiver: carol,
            depositAmount: depositAmount * 2,
            keeperFeeAmount: 0
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        executeStableDeposit(keeper, bob, currentPrice);
        executeStableDeposit(keeper, carol, currentPrice);

        assertEq(stableModProxy.balanceOf(bob), bobLPQuote, "Bob should have the correct balance");
        assertEq(stableModProxy.balanceOf(carol), carolLPQuote, "Carol should have the correct balance");

        announceOpenLeverage({traderAccount: bob, margin: 1e18, additionalSize: 1e18, keeperFeeAmount: 0});
        announceOpenLeverageFor({
            traderAccount: bob,
            receiver: carol,
            margin: 2e18,
            additionalSize: 2e18,
            stopLossPrice: 0,
            profitTakePrice: type(uint256).max,
            keeperFeeAmount: 0
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        uint256 tokenIdBob = executeOpenLeverage(keeper, bob, currentPrice);
        uint256 tokenIdCarol = executeOpenLeverage(keeper, carol, currentPrice);

        assertEq(leverageModProxy.ownerOf(tokenIdBob), bob, "Bob should be the owner of the token");
        assertEq(leverageModProxy.ownerOf(tokenIdCarol), carol, "Carol should be the owner of the token");
        assertEq(leverageModProxy.getPositionSummary(tokenIdBob).marginAfterSettlement, 1e18);
        assertEq(leverageModProxy.getPositionSummary(tokenIdCarol).marginAfterSettlement, 2e18);
    }

    function test_announce_leverage_open_with_limits() public {
        uint256 depositAmount = 100 ether;
        uint256 currentPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenWithLimits({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 50 ether,
            additionalSize: 50 ether,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 bobBalanceBeforeClose = collateralAsset.balanceOf(bob);

        DelayedOrderStructs.AnnouncedLimitClose memory limitOrder = abi.decode(
            orderAnnouncementModProxy.getLimitOrder(tokenId).orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        assertTrue(leverageModProxy.ownerOf(tokenId) == bob, "Bob should have received a leverage NFT");
        assertTrue(limitOrder.stopLossPrice == 900e18, "Bob's limit order should have the correct stop loss price");
        assertTrue(
            limitOrder.profitTakePrice == 1100e18,
            "Bob's limit order should have the correct profit take price"
        );

        setCollateralPrice(900e8);
        skip(1 days);

        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        uint256 tradeFee = FeeManager(address(vaultProxy)).getTradeFee(50 ether);
        bytes[] memory priceUpdateData = getPriceUpdateData(900e8);

        vm.startPrank(keeper);
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            bobBalanceBeforeClose + uint256(settledMargin) - tradeFee - mockKeeperFee.getKeeperFee(),
            collateralAsset.balanceOf(bob),
            "Bob should have received the correct amount after limit order execution"
        );
    }

    function test_announceFor_leverage_open_with_stopLoss() public {
        uint256 depositAmount = 100 ether;
        uint256 currentPrice = 1000e8;
        uint256 bobBalanceBefore = collateralAsset.balanceOf(bob);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            margin: 50 ether,
            additionalSize: 50 ether,
            stopLossPrice: 900e18,
            profitTakePrice: type(uint256).max,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        DelayedOrderStructs.AnnouncedLimitClose memory limitOrder = abi.decode(
            orderAnnouncementModProxy.getLimitOrder(tokenId).orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        assertTrue(leverageModProxy.ownerOf(tokenId) == bob, "Bob should have received a leverage NFT");
        assertTrue(limitOrder.stopLossPrice == 900e18, "Bob's limit order should have the correct stop loss price");
        assertTrue(
            limitOrder.profitTakePrice == type(uint256).max,
            "Bob's limit order should have the correct profit take price"
        );

        setCollateralPrice(900e8);
        skip(1 days);

        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        uint256 tradeFee = FeeManager(address(vaultProxy)).getTradeFee(50 ether);
        bytes[] memory priceUpdateData = getPriceUpdateData(900e8);

        vm.startPrank(keeper);
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            bobBalanceBefore + uint256(settledMargin) - tradeFee - mockKeeperFee.getKeeperFee(),
            collateralAsset.balanceOf(bob),
            "Bob should have received the correct amount after limit order execution"
        );
    }

    function test_announceFor_leverage_open_with_profitTake() public {
        uint256 depositAmount = 100 ether;
        uint256 currentPrice = 1000e8;
        uint256 bobBalanceBefore = collateralAsset.balanceOf(bob);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            margin: 50 ether,
            additionalSize: 50 ether,
            stopLossPrice: 0,
            profitTakePrice: 1100e18,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        DelayedOrderStructs.AnnouncedLimitClose memory limitOrder = abi.decode(
            orderAnnouncementModProxy.getLimitOrder(tokenId).orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        assertTrue(leverageModProxy.ownerOf(tokenId) == bob, "Bob should have received a leverage NFT");
        assertTrue(limitOrder.stopLossPrice == 0, "Bob's limit order should have the correct stop loss price");
        assertTrue(
            limitOrder.profitTakePrice == 1100e18,
            "Bob's limit order should have the correct profit take price"
        );

        setCollateralPrice(1100e8);
        skip(1 days);

        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        uint256 tradeFee = FeeManager(address(vaultProxy)).getTradeFee(50 ether);
        bytes[] memory priceUpdateData = getPriceUpdateData(1100e8);

        vm.startPrank(keeper);
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            bobBalanceBefore + uint256(settledMargin) - tradeFee - mockKeeperFee.getKeeperFee(),
            collateralAsset.balanceOf(bob),
            "Bob should have received the correct amount after limit order execution"
        );
    }

    function test_announceFor_leverage_open_with_both_limits() public {
        uint256 depositAmount = 100 ether;
        uint256 currentPrice = 1000e8;
        uint256 bobBalanceBefore = collateralAsset.balanceOf(bob);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            margin: 50 ether,
            additionalSize: 50 ether,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        DelayedOrderStructs.AnnouncedLimitClose memory limitOrder = abi.decode(
            orderAnnouncementModProxy.getLimitOrder(tokenId).orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        assertTrue(leverageModProxy.ownerOf(tokenId) == bob, "Bob should have received a leverage NFT");
        assertEq(limitOrder.stopLossPrice, 900e18, "Bob's limit order should have the correct stop loss price");
        assertEq(limitOrder.profitTakePrice, 1100e18, "Bob's limit order should have the correct profit take price");
        assertEq(
            collateralAsset.balanceOf(bob),
            bobBalanceBefore,
            "Bob's balance should not change after leverage open"
        );
    }

    function test_announceFor_cancel_deposit() public {
        uint256 depositAmount = 1e18;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 bobBalanceBefore = collateralAsset.balanceOf(bob);

        announceStableDepositFor(alice, bob, depositAmount, 0);

        assertEq(
            uint256(orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType),
            uint256(DelayedOrderStructs.OrderType.None),
            "Order should not exist for Alice"
        );
        assertEq(
            uint256(orderAnnouncementModProxy.getAnnouncedOrder(bob).orderType),
            uint256(DelayedOrderStructs.OrderType.StableDeposit),
            "Order should exist for Bob"
        );
        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect before cancel"
        );
        assertEq(bobBalanceBefore, collateralAsset.balanceOf(bob), "Bob's balance incorrect before cancel");

        vm.startPrank(alice);

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);

        // Nothing should happen if cancelling Alice's order (order should be under Bob's account)
        orderExecutionModProxy.cancelExistingOrder(alice);
        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance shouldn't change after cancelling non-existant order"
        );
        assertEq(
            bobBalanceBefore,
            collateralAsset.balanceOf(bob),
            "Bob's balance shouldn't change after cancelling non-existant order"
        );

        orderExecutionModProxy.cancelExistingOrder(bob);

        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect after cancel"
        );
        assertEq(
            bobBalanceBefore,
            collateralAsset.balanceOf(bob) - depositAmount - keeperFee,
            "Bob's balance incorrect after cancel"
        );
    }

    function test_announceFor_cancel_leverage() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 bobBalanceBefore = collateralAsset.balanceOf(bob);

        announceOpenLeverageFor({
            traderAccount: alice,
            receiver: bob,
            margin: depositAmount,
            additionalSize: depositAmount,
            stopLossPrice: 0,
            profitTakePrice: type(uint256).max,
            keeperFeeAmount: 0
        });

        assertEq(
            uint256(orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType),
            uint256(DelayedOrderStructs.OrderType.None),
            "Order should not exist for Alice"
        );
        assertEq(
            uint256(orderAnnouncementModProxy.getAnnouncedOrder(bob).orderType),
            uint256(DelayedOrderStructs.OrderType.LeverageOpen),
            "Order should exist for Bob"
        );
        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect before cancel"
        );
        assertEq(bobBalanceBefore, collateralAsset.balanceOf(bob), "Bob's balance incorrect before cancel");

        vm.startPrank(alice);

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);

        // Nothing should happen if cancelling Alice's order (order should be under Bob's account)
        orderExecutionModProxy.cancelExistingOrder(alice);
        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance shouldn't change after cancelling non-existant order"
        );
        assertEq(
            bobBalanceBefore,
            collateralAsset.balanceOf(bob),
            "Bob's balance shouldn't change after cancelling non-existant order"
        );

        orderExecutionModProxy.cancelExistingOrder(bob);

        assertEq(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect after cancel"
        );
        assertEq(
            bobBalanceBefore,
            collateralAsset.balanceOf(bob) - depositAmount - keeperFee,
            "Bob's balance incorrect after cancel"
        );
    }

    function test_announce_deposit_has_proper_spender_set_in_order() public {
        announceStableDepositFor({traderAccount: bob, receiver: carol, depositAmount: 2e18, keeperFeeAmount: 0});

        DelayedOrderStructs.Order memory firstOrder = orderAnnouncementModProxy.getAnnouncedOrder(carol);
        DelayedOrderStructs.AnnouncedStableDeposit memory firstStableDeposit = abi.decode(
            firstOrder.orderData,
            (DelayedOrderStructs.AnnouncedStableDeposit)
        );
        assertEq(firstStableDeposit.announcedBy, bob);

        announceStableDeposit({traderAccount: bob, depositAmount: 1e18, keeperFeeAmount: 0});

        DelayedOrderStructs.Order memory secondOrder = orderAnnouncementModProxy.getAnnouncedOrder(bob);
        DelayedOrderStructs.AnnouncedStableDeposit memory secondStableDeposit = abi.decode(
            secondOrder.orderData,
            (DelayedOrderStructs.AnnouncedStableDeposit)
        );
        assertEq(secondStableDeposit.announcedBy, bob);
    }

    function test_announce_leverage_open_has_proper_spender_set_in_order() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 4e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        announceOpenLeverageFor({
            traderAccount: bob,
            receiver: carol,
            margin: 2e18,
            additionalSize: 2e18,
            stopLossPrice: 0,
            profitTakePrice: type(uint256).max,
            keeperFeeAmount: 0
        });

        DelayedOrderStructs.Order memory firstOrder = orderAnnouncementModProxy.getAnnouncedOrder(carol);
        DelayedOrderStructs.AnnouncedLeverageOpen memory firstLeverageOpen = abi.decode(
            firstOrder.orderData,
            (DelayedOrderStructs.AnnouncedLeverageOpen)
        );
        assertEq(firstLeverageOpen.announcedBy, bob);

        announceOpenLeverage({traderAccount: bob, margin: 1e18, additionalSize: 1e18, keeperFeeAmount: 0});

        DelayedOrderStructs.Order memory secondOrder = orderAnnouncementModProxy.getAnnouncedOrder(bob);
        DelayedOrderStructs.AnnouncedLeverageOpen memory secondLeverageOpen = abi.decode(
            secondOrder.orderData,
            (DelayedOrderStructs.AnnouncedLeverageOpen)
        );
        assertEq(secondLeverageOpen.announcedBy, bob);
    }

    function test_revert_announceFor_when_caller_not_authorized() public {
        address unAuthorizedAccount = makeAddr("unAuthorizedAccount");

        vm.startPrank(unAuthorizedAccount);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "OnlyAuthorizedCaller(address)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.OnlyAuthorizedCaller.selector,
                unAuthorizedAccount
            )
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpenFor.selector,
                0,
                0,
                0,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "OnlyAuthorizedCaller(address)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.OnlyAuthorizedCaller.selector,
                unAuthorizedAccount
            )
        });
    }

    function test_revert_announceFor_when_module_paused() public {
        bytes32 moduleKey = orderAnnouncementModProxy.MODULE_KEY();

        vm.startPrank(admin);

        vaultProxy.pauseModule(moduleKey);

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, moduleKey)
        });

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpenFor.selector,
                0,
                0,
                0,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, moduleKey)
        });
    }

    function test_revert_announceFor_deposit_when_deposit_amount_too_small() public {
        uint256 depositAmount = 100;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);

        uint256 depositAmountUSD = (depositAmount * collateralAssetPrice) / (10 ** collateralAsset.decimals());

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "AmountTooSmall(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.AmountTooSmall.selector,
                depositAmountUSD,
                orderAnnouncementModProxy.minDepositAmountUSD()
            )
        });
    }

    function test_revert_announceFor_deposit_when_slippage_is_high() public {
        uint256 depositAmount = 0.1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 minAmountOut = quotedAmount * 2;

        vm.startPrank(alice);

        collateralAsset.approve(address(orderAnnouncementModProxy), depositAmount + mockKeeperFee.getKeeperFee());

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                depositAmount,
                minAmountOut,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "HighSlippage(uint256,uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.HighSlippage.selector, quotedAmount, minAmountOut)
        });
    }

    function test_revert_announceFor_deposit_when_keeper_fee_too_small() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = 0;

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                alice
            ),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.InvalidFee.selector, keeperFee)
        });
    }

    function test_revert_announceFor_deposit_when_deposit_amount_not_approved() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        _expectRevertWith({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                alice
            ),
            revertMessage: "ERC20: subtraction underflow"
        });
    }

    function test_revert_announceFor_deposit_when_previous_order_has_not_expired() public {
        vm.startPrank(alice);

        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        collateralAsset.approve(address(orderAnnouncementModProxy), (depositAmount + keeperFee) * 2);

        orderAnnouncementModProxy.announceStableDepositFor(depositAmount, quotedAmount, keeperFee, bob);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                bob
            ),
            expectedErrorSignature: "OrderHasNotExpired()",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderHasNotExpired.selector)
        });
    }

    function test_revert_announceFor_withdraw_when_amount_not_enough() public {
        uint256 currentPrice = 1000e8;
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 1e18;
        uint256 liquidityMinted = stableModProxy.stableDepositQuote(depositAmount);

        announceAndExecuteDepositFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

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

        uint256 aliceStableBalance = stableModProxy.balanceOf(alice);
        uint256 bobStableBalance = stableModProxy.balanceOf(bob);

        assertEq(aliceStableBalance, 0);
        assertEq(bobStableBalance, liquidityMinted);

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: bobStableBalance,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });
    }

    function test_revert_announceFor_open_when_price_too_low() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        announceAndExecuteDepositFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 maxFillPrice = 900e18;

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageOpenFor.selector,
                depositAmount,
                depositAmount,
                maxFillPrice,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                bob
            ),
            expectedErrorSignature: "MaxFillPriceTooLow(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.MaxFillPriceTooLow.selector,
                maxFillPrice,
                currentPrice * 1e10
            )
        });
    }

    function test_revert_announceFor_close_when_caller_not_token_owner() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        announceAndExecuteDepositFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpenFor({
            traderAccount: alice,
            receiver: bob,
            keeperAccount: keeper,
            margin: depositAmount,
            additionalSize: depositAmount,
            stopLossPrice: 0,
            profitTakePrice: type(uint256).max,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                orderAnnouncementModProxy.announceLeverageClose.selector,
                tokenId,
                currentPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(ICommonErrors.NotTokenOwner.selector, tokenId, alice)
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });
    }

    function test_revert_announceFor_leverage_open_with_invalid_limits() public {
        uint256 depositAmount = 100 ether;
        uint256 currentPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        uint256 margin = 50 ether;
        uint256 additionalSize = 50 ether;
        uint256 stopLossPrice = 1100e18;
        uint256 profitTakePrice = 1000e18;

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSignature(
                "announceOpenLeverageFor(address,address,uint256,uint256,uint256,uint256,uint256)",
                alice,
                bob,
                margin,
                additionalSize,
                stopLossPrice,
                profitTakePrice,
                0
            ),
            expectedErrorSignature: "InvalidLimitOrderPrices(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderAnnouncementModule.InvalidLimitOrderPrices.selector,
                stopLossPrice,
                profitTakePrice
            )
        });
    }
}
