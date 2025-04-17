// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "forge-std/console2.sol";

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import "../../../src/interfaces/IChainlinkAggregatorV3.sol";

contract PositionLockTest is OrderHelpers {
    function test_transfer_when_leverage_close_order_cancelled() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        (uint256 minFillPrice, ) = oracleModProxy.getPrice(address(vaultProxy.collateral()));

        vm.startPrank(alice);

        // Announce the order
        orderAnnouncementModProxy.announceLeverageClose({
            tokenId_: tokenId,
            minFillPrice_: minFillPrice,
            keeperFee_: mockKeeperFee.getKeeperFee()
        });

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageClose)
        );

        // Try to transfer the position.
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});

        // Skip some time so that the order expires.
        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);

        // Cancel the order.
        orderExecutionModProxy.cancelExistingOrder(alice);

        assertEq(leverageModProxy.ownerOf(tokenId), alice, "Alice should be the owner of the position NFT");

        vm.startPrank(alice);

        // Try to transfer the position.
        leverageModProxy.safeTransferFrom({from: alice, to: bob, tokenId: tokenId});

        assertEq(leverageModProxy.ownerOf(tokenId), bob, "Bob should be the owner of the position NFT");
    }

    function test_revert_transfer_when_leverage_close_order_announced() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        (uint256 minFillPrice, ) = oracleModProxy.getPrice(address(vaultProxy.collateral()));

        vm.startPrank(alice);

        // Announce the order
        orderAnnouncementModProxy.announceLeverageClose({
            tokenId_: tokenId,
            minFillPrice_: minFillPrice,
            keeperFee_: mockKeeperFee.getKeeperFee()
        });

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageClose)
        );

        // Try to transfer the position.
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});

        // Skip some time to make the order executable.
        skip(orderAnnouncementModProxy.minExecutabilityAge() + 1);

        // Execute the order
        executeCloseLeverage({keeperAccount: keeper, traderAccount: alice, oraclePrice: 1000e8});
    }

    function test_revert_transfer_when_limit_open_and_adjust() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LimitClose)
        );

        // Try to transfer the position.
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    function test_revert_lock_when_close_cancelled() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        orderAnnouncementModProxy.announceLeverageClose({
            tokenId_: tokenId,
            minFillPrice_: 0,
            keeperFee_: mockKeeperFee.getKeeperFee()
        });

        skip(orderAnnouncementModProxy.minExecutabilityAge() + orderExecutionModProxy.maxExecutabilityAge() + 1);

        orderExecutionModProxy.cancelExistingOrder(alice);

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LimitClose)
        );
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    function test_revert_transfer_when_adjust_cancelled() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        announceAdjustLeverage({
            tokenId: tokenId,
            traderAccount: alice,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            keeperFeeAmount: 0
        });

        skip(orderAnnouncementModProxy.minExecutabilityAge() + orderExecutionModProxy.maxExecutabilityAge() + 1);

        orderExecutionModProxy.cancelExistingOrder(alice);

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LimitClose)
        );
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    function test_revert_transfer_when_limit_cancelled() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        orderAnnouncementModProxy.announceLeverageClose({
            tokenId_: tokenId,
            minFillPrice_: 0,
            keeperFee_: mockKeeperFee.getKeeperFee()
        });

        orderAnnouncementModProxy.cancelLimitOrder(tokenId);

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageClose)
        );
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }
}
