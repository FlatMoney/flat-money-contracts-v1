// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "../../../src/libraries/FlatcoinStructs.sol";

import "forge-std/console2.sol";

contract AnnounceForTest is OrderHelpers, ExpectRevert {
    function test_announceFor_deposit_open_close() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;
        uint256 aliceBalanceBefore = WETH.balanceOf(alice);

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
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            aliceBalanceBefore - WETH.balanceOf(alice),
            (depositAmount + mockKeeperFee.getKeeperFee()) * 2,
            "Alice should have the correct WETH balance after leverage open"
        );
        assertEq(leverageModProxy.balanceOf(alice), 0, "Alice should have no leverage token balance");
        assertEq(stableModProxy.balanceOf(alice), 0, "Alice should have no LP balance");
        assertEq(stableModProxy.balanceOf(bob), depositAmount, "Bob's LP token balance incorrect");
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

        assertEq(WETH.balanceOf(address(vaultProxy)), 0, "Should be no balance remaining in contracts");
    }

    function test_announceFor_deposit_open_multiple() public {
        uint256 depositAmount = 1e18;
        uint256 currentPrice = 1000e8;

        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        announceStableDeposit({traderAccount: bob, depositAmount: 1e18, keeperFeeAmount: 0});
        announceStableDepositFor({traderAccount: bob, receiver: carol, depositAmount: 2e18, keeperFeeAmount: 0});

        skip(uint256(vaultProxy.minExecutabilityAge()));

        executeStableDeposit(keeper, bob, currentPrice);
        executeStableDeposit(keeper, carol, currentPrice);

        assertEq(stableModProxy.balanceOf(bob), 1e18, "Bob should have the correct balance");
        assertEq(stableModProxy.balanceOf(carol), 2e18, "Carol should have the correct balance");

        announceOpenLeverage({traderAccount: bob, margin: 1e18, additionalSize: 1e18, keeperFeeAmount: 0});
        announceOpenLeverageFor({
            traderAccount: bob,
            receiver: carol,
            margin: 2e18,
            additionalSize: 2e18,
            keeperFeeAmount: 0
        });

        skip(uint256(vaultProxy.minExecutabilityAge()));

        uint256 tokenIdBob = executeOpenLeverage(keeper, bob, currentPrice);
        uint256 tokenIdCarol = executeOpenLeverage(keeper, carol, currentPrice);

        assertEq(leverageModProxy.ownerOf(tokenIdBob), bob, "Bob should be the owner of the token");
        assertEq(leverageModProxy.ownerOf(tokenIdCarol), carol, "Carol should be the owner of the token");
        assertEq(leverageModProxy.getPositionSummary(tokenIdBob).marginAfterSettlement, 1e18);
        assertEq(leverageModProxy.getPositionSummary(tokenIdCarol).marginAfterSettlement, 2e18);
    }

    function test_announceFor_cancel_deposit() public {
        uint256 depositAmount = 1e18;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 aliceBalanceBefore = WETH.balanceOf(alice);
        uint256 bobBalanceBefore = WETH.balanceOf(bob);

        announceStableDepositFor(alice, bob, depositAmount, 0);

        assertEq(
            uint256(delayedOrderProxy.getAnnouncedOrder(alice).orderType),
            uint256(FlatcoinStructs.OrderType.None),
            "Order should not exist for Alice"
        );
        assertEq(
            uint256(delayedOrderProxy.getAnnouncedOrder(bob).orderType),
            uint256(FlatcoinStructs.OrderType.StableDeposit),
            "Order should exist for Bob"
        );
        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect before cancel"
        );
        assertEq(bobBalanceBefore, WETH.balanceOf(bob), "Bob's balance incorrect before cancel");

        vm.startPrank(alice);

        skip(vaultProxy.maxExecutabilityAge() + vaultProxy.minExecutabilityAge() + 1);

        // Nothing should happen if cancelling Alice's order (order should be under Bob's account)
        delayedOrderProxy.cancelExistingOrder(alice);
        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance shouldn't change after cancelling non-existant order"
        );
        assertEq(
            bobBalanceBefore,
            WETH.balanceOf(bob),
            "Bob's balance shouldn't change after cancelling non-existant order"
        );

        delayedOrderProxy.cancelExistingOrder(bob);

        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect after cancel"
        );
        assertEq(
            bobBalanceBefore,
            WETH.balanceOf(bob) - depositAmount - keeperFee,
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

        uint256 aliceBalanceBefore = WETH.balanceOf(alice);
        uint256 bobBalanceBefore = WETH.balanceOf(bob);

        announceOpenLeverageFor({
            traderAccount: alice,
            receiver: bob,
            margin: depositAmount,
            additionalSize: depositAmount,
            keeperFeeAmount: 0
        });

        assertEq(
            uint256(delayedOrderProxy.getAnnouncedOrder(alice).orderType),
            uint256(FlatcoinStructs.OrderType.None),
            "Order should not exist for Alice"
        );
        assertEq(
            uint256(delayedOrderProxy.getAnnouncedOrder(bob).orderType),
            uint256(FlatcoinStructs.OrderType.LeverageOpen),
            "Order should exist for Bob"
        );
        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect before cancel"
        );
        assertEq(bobBalanceBefore, WETH.balanceOf(bob), "Bob's balance incorrect before cancel");

        vm.startPrank(alice);

        skip(vaultProxy.maxExecutabilityAge() + vaultProxy.minExecutabilityAge() + 1);

        // Nothing should happen if cancelling Alice's order (order should be under Bob's account)
        delayedOrderProxy.cancelExistingOrder(alice);
        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance shouldn't change after cancelling non-existant order"
        );
        assertEq(
            bobBalanceBefore,
            WETH.balanceOf(bob),
            "Bob's balance shouldn't change after cancelling non-existant order"
        );

        delayedOrderProxy.cancelExistingOrder(bob);

        assertEq(
            aliceBalanceBefore,
            WETH.balanceOf(alice) + depositAmount + keeperFee,
            "Alice's balance incorrect after cancel"
        );
        assertEq(
            bobBalanceBefore,
            WETH.balanceOf(bob) - depositAmount - keeperFee,
            "Bob's balance incorrect after cancel"
        );
    }

    function test_revert_announceFor_when_module_paused() public {
        bytes32 moduleKey = delayedOrderProxy.MODULE_KEY();

        vm.prank(admin);
        vaultProxy.pauseModule(moduleKey);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.Paused.selector, moduleKey)
        });

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceLeverageOpenFor.selector,
                0,
                0,
                0,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.Paused.selector, moduleKey)
        });
    }

    function test_revert_announceFor_deposit_when_deposit_amount_too_small() public {
        uint256 depositAmount = 100;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "AmountTooSmall(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                FlatcoinErrors.AmountTooSmall.selector,
                depositAmount,
                delayedOrderProxy.MIN_DEPOSIT()
            )
        });
    }

    function test_revert_announceFor_deposit_when_slippage_is_high() public {
        uint256 depositAmount = 0.1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 minAmountOut = 1e18;

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                depositAmount,
                minAmountOut,
                mockKeeperFee.getKeeperFee(),
                alice
            ),
            expectedErrorSignature: "HighSlippage(uint256,uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.HighSlippage.selector, quotedAmount, minAmountOut)
        });
    }

    function test_revert_announceFor_deposit_when_keeper_fee_too_small() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = 0;

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                alice
            ),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidFee.selector, keeperFee)
        });
    }

    function test_revert_announceFor_deposit_when_deposit_amount_not_approved() public {
        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                alice
            ),
            expectedErrorSignature: "ERC20InsufficientAllowance(address,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                delayedOrderProxy,
                0,
                depositAmount + keeperFee
            )
        });
    }

    function test_revert_announceFor_deposit_when_previous_order_has_not_expired() public {
        vm.startPrank(alice);

        uint256 depositAmount = 1e18;
        uint256 quotedAmount = stableModProxy.stableDepositQuote(depositAmount);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        WETH.approve(address(delayedOrderProxy), (depositAmount + keeperFee) * 2);

        delayedOrderProxy.announceStableDepositFor(depositAmount, quotedAmount, keeperFee, bob);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableDepositFor.selector,
                depositAmount,
                quotedAmount,
                keeperFee,
                bob
            ),
            expectedErrorSignature: "OrderHasNotExpired()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OrderHasNotExpired.selector)
        });
    }

    function test_revert_announceFor_withdraw_when_amount_not_enough() public {
        uint256 currentPrice = 1000e8;
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 1e18;

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
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceStableWithdraw.selector,
                withdrawAmount,
                0,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "NotEnoughBalanceForWithdraw(address,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                FlatcoinErrors.NotEnoughBalanceForWithdraw.selector,
                alice,
                0,
                withdrawAmount
            )
        });

        uint256 aliceStableBalance = stableModProxy.balanceOf(alice);
        uint256 bobStableBalance = stableModProxy.balanceOf(bob);

        assertEq(aliceStableBalance, 0);
        assertEq(bobStableBalance, depositAmount);

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

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceLeverageOpenFor.selector,
                depositAmount,
                depositAmount,
                maxFillPrice,
                mockKeeperFee.getKeeperFee(),
                bob
            ),
            expectedErrorSignature: "MaxFillPriceTooLow(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                FlatcoinErrors.MaxFillPriceTooLow.selector,
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
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(
                delayedOrderProxy.announceLeverageClose.selector,
                tokenId,
                currentPrice,
                mockKeeperFee.getKeeperFee()
            ),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.NotTokenOwner.selector, tokenId, alice)
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: currentPrice,
            keeperFeeAmount: 0
        });
    }
}
