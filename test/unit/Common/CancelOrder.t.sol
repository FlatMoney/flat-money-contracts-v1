// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract CancelDepositTest is OrderHelpers {
    function test_cancel_deposit() public {
        cancelDeposit();
        cancelDeposit();
        cancelDeposit(); // third one for luck, just to make sure it all works
    }

    function test_cancel_withdraw() public {
        cancelWithdraw();
        cancelWithdraw();
        cancelWithdraw();
    }

    function test_cancel_leverage_open() public {
        cancelLeverageOpen();
        cancelLeverageOpen();
        cancelLeverageOpen();
    }

    function test_cancel_leverage_close() public {
        cancelLeverageClose();
        cancelLeverageClose();
        cancelLeverageClose();
    }

    // TODO: Consider moving helper functions to a separate contract

    function cancelDeposit() public {
        setCollateralPrice(2000e8);
        skip(120);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceStableDeposit({traderAccount: alice, depositAmount: 100e18, keeperFeeAmount: 0});

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);
        vm.startPrank(alice);
        orderExecutionModProxy.cancelExistingOrder(alice);

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(alice);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None), "Order not cancelled");

        assertTrue(order.orderData.length == 0, "Order not cancelled");
    }

    function cancelWithdraw() public {
        setCollateralPrice(2000e8);
        skip(120);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceStableWithdraw({traderAccount: alice, withdrawAmount: 100e18, keeperFeeAmount: 0});

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);
        vm.startPrank(alice);
        orderExecutionModProxy.cancelExistingOrder(alice);

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(alice);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None), "Order not cancelled");

        assertTrue(order.orderData.length == 0, "Order not cancelled");
    }

    function cancelLeverageOpen() public {
        setCollateralPrice(2000e8);
        skip(120);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceOpenLeverage({traderAccount: alice, margin: 100e18, additionalSize: 100e18, keeperFeeAmount: 0});

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);
        vm.startPrank(alice);
        orderExecutionModProxy.cancelExistingOrder(alice);

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(alice);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None), "Order not cancelled");

        assertTrue(order.orderData.length == 0, "Order not cancelled");
    }

    function cancelLeverageClose() public {
        setCollateralPrice(2000e8);
        skip(120);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId0 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceCloseLeverage({traderAccount: alice, tokenId: tokenId0, keeperFeeAmount: 0});

        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);

        vm.startPrank(alice);
        orderExecutionModProxy.cancelExistingOrder(alice);

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getAnnouncedOrder(alice);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None), "Order not cancelled");

        assertTrue(order.orderData.length == 0, "Order not cancelled");
    }
}
