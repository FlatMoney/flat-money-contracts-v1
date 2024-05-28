// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import "forge-std/console2.sol";

import {Setup} from "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import "../../../src/interfaces/IChainlinkAggregatorV3.sol";

contract PositionLockTest is Setup, OrderHelpers {
    function test_lock_when_leverage_close_order_announced() public {
        setWethPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        (uint256 minFillPrice, ) = oracleModProxy.getPrice();

        vm.startPrank(alice);

        // Announce the order
        delayedOrderProxy.announceLeverageClose({
            tokenId: tokenId,
            minFillPrice: minFillPrice,
            keeperFee: mockKeeperFee.getKeeperFee()
        });

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");

        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");

        // Try to transfer the position.
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});

        // Skip some time to make the order executable.
        skip(vaultProxy.minExecutabilityAge() + 1);

        // Execute the order
        executeCloseLeverage({keeperAccount: keeper, traderAccount: alice, oraclePrice: 1000e8});
    }

    function test_unlock_when_leverage_close_order_cancelled() public {
        setWethPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        (uint256 minFillPrice, ) = oracleModProxy.getPrice();

        vm.startPrank(alice);

        // Announce the order
        delayedOrderProxy.announceLeverageClose({
            tokenId: tokenId,
            minFillPrice: minFillPrice,
            keeperFee: mockKeeperFee.getKeeperFee()
        });

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");

        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");

        // Try to transfer the position.
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});

        // Skip some time so that the order expires.
        skip(vaultProxy.maxExecutabilityAge() + vaultProxy.minExecutabilityAge() + 1);

        // Cancel the order.
        delayedOrderProxy.cancelExistingOrder(alice);

        assertFalse(leverageModProxy.isLocked(tokenId), "Position NFT should be unlocked");
        assertEq(leverageModProxy.ownerOf(tokenId), alice, "Alice should be the owner of the position NFT");

        vm.startPrank(alice);

        // Try to transfer the position.
        leverageModProxy.safeTransferFrom({from: alice, to: bob, tokenId: tokenId});

        assertEq(leverageModProxy.ownerOf(tokenId), bob, "Bob should be the owner of the position NFT");
    }

    /// @dev This test checks for incorrect unlock of a position that can occur due to one module unlocking the position
    ///      which was locked by another module.
    ///      In this particular case a limit order has locked a position but adjusting the position using DelayedOrder unlocks the position.
    function test_lock_when_limit_open_and_adjust() public {
        setWethPrice(1000e8);

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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
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

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");
        assertTrue(
            leverageModProxy.exposed_lockedByModule(tokenId, LIMIT_ORDER_KEY),
            "Position NFT should be locked by LimitOrder module"
        );

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    /// @dev This test checks for incorrect unlock of a position that can occur due to one module unlocking the position
    ///      which was locked by another module.
    ///      In this particular case, the position was locked by the LimitOrder module and also by DelayedOrder when a close order was announced.
    ///      Then the close order expired and user calls `cancelExistingOrder`. This means DelayedOrder unlocks its lock on the position.
    ///      This shouldn't unlock the position as the position is still locked by the LimitOrder module.
    function test_lock_when_close_cancelled() public {
        setWethPrice(1000e8);

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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        delayedOrderProxy.announceLeverageClose({
            tokenId: tokenId,
            minFillPrice: 0,
            keeperFee: mockKeeperFee.getKeeperFee()
        });

        skip(vaultProxy.minExecutabilityAge() + vaultProxy.maxExecutabilityAge() + 1);

        delayedOrderProxy.cancelExistingOrder(alice);

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");
        assertTrue(
            leverageModProxy.exposed_lockedByModule(tokenId, LIMIT_ORDER_KEY),
            "Position NFT should be locked by LimitOrder module"
        );

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    /// @dev This test checks for incorrect unlock of a position that can occur due to one module unlocking the position
    ///      which was locked by another module.
    ///      In this particular case, the position was locked by the LimitOrder module and also by DelayedOrder when an adjust order was announced.
    ///      Then the adjust order was cancelled after expiration. This means DelayedOrder unlocks its lock on the position.
    ///      This shouldn't unlock the position as the position is still locked by the LimitOrder module.
    function test_lock_when_adjust_cancelled() public {
        setWethPrice(1000e8);

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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        announceAdjustLeverage({
            tokenId: tokenId,
            traderAccount: alice,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            keeperFeeAmount: 0
        });

        skip(vaultProxy.minExecutabilityAge() + vaultProxy.maxExecutabilityAge() + 1);

        delayedOrderProxy.cancelExistingOrder(alice);

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");
        assertTrue(
            leverageModProxy.exposed_lockedByModule(tokenId, LIMIT_ORDER_KEY),
            "Position NFT should be locked by LimitOrder module"
        );

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }

    /// @dev This test checks for incorrect unlock of a position that can occur due to one module unlocking the position
    ///      which was locked by another module.
    ///      In this particular case, the position was locked by the LimitOrder module and also by DelayedOrder when a close order was announced.
    ///      Then the limit order was cancelled. This means LimitOrder unlocks its lock on the position.
    ///      This shouldn't unlock the position as the position is still locked by the DelayedOrder module.
    function test_lock_when_limit_cancelled() public {
        setWethPrice(1000e8);

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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        delayedOrderProxy.announceLeverageClose({
            tokenId: tokenId,
            minFillPrice: 0,
            keeperFee: mockKeeperFee.getKeeperFee()
        });

        limitOrderProxy.cancelLimitOrder(tokenId);

        assertTrue(leverageModProxy.isLocked(tokenId), "Position NFT should be locked");
        assertTrue(
            leverageModProxy.exposed_lockedByModule(tokenId, DELAYED_ORDER_KEY),
            "Position NFT should be locked by DelayedOrder module"
        );

        vm.startPrank(alice);

        // Try to transfer the position.
        vm.expectRevert("ERC721LockableEnumerableUpgradeable: token is locked");
        leverageModProxy.transferFrom({from: alice, to: bob, tokenId: tokenId});
    }
}
