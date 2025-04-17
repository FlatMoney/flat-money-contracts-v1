// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../helpers/OrderHelpers.sol";

contract LPTokenLock is OrderHelpers {
    using SafeERC20 for IERC20;

    function test_unlock_when_stable_withdraw_order_expired() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 aliceLPBalanceBefore = stableModProxy.balanceOf(alice);
        uint256 withdrawAmount = aliceLPBalanceBefore;

        // Announce redemption of a portion of the LP tokens.
        announceStableWithdraw({traderAccount: alice, withdrawAmount: withdrawAmount, keeperFeeAmount: 0});

        // Skip some time so that the order expires.
        skip(orderExecutionModProxy.maxExecutabilityAge() + orderAnnouncementModProxy.minExecutabilityAge() + 1);

        vm.startPrank(alice);

        // Cancel the order.
        orderExecutionModProxy.cancelExistingOrder(alice);

        assertEq(stableModProxy.getLockedAmount(alice), 0, "Locked amount should be 0");
        assertEq(stableModProxy.balanceOf(alice), aliceLPBalanceBefore, "Alice should have all the LP tokens");

        // When trying to transfer all the LP tokens, the transaction should not revert.
        IERC20(address(stableModProxy)).safeTransfer({to: bob, value: aliceLPBalanceBefore});

        assertEq(stableModProxy.balanceOf(bob), aliceLPBalanceBefore, "Bob should have gotten all the LP tokens");
    }

    function test_revert_lock_partial_stable_withdraw_announced() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 aliceLPBalanceBefore = stableModProxy.balanceOf(alice);
        uint256 withdrawAmount = aliceLPBalanceBefore / 2;

        // Announce redemption of a portion of the LP tokens.
        announceStableWithdraw({traderAccount: alice, withdrawAmount: withdrawAmount, keeperFeeAmount: 0});

        vm.startPrank(alice);

        // When trying to transfer all the LP tokens, the transaction should revert.
        vm.expectRevert("ERC20LockableUpgradeable: insufficient unlocked balance");

        stableModProxy.transfer(bob, aliceLPBalanceBefore);

        // Skip some time to make the order executable.
        skip(orderAnnouncementModProxy.minExecutabilityAge() + 1);

        executeStableWithdraw({traderAccount: alice, keeperAccount: keeper, oraclePrice: 1000e8});
    }

    function test_revert_lock_full_stable_withdraw_announced() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 aliceLPBalanceBefore = stableModProxy.balanceOf(alice);
        uint256 withdrawAmount = aliceLPBalanceBefore;

        // Announce redemption of a portion of the LP tokens.
        announceStableWithdraw({traderAccount: alice, withdrawAmount: withdrawAmount, keeperFeeAmount: 0});

        vm.startPrank(alice);

        // When trying to transfer all the LP tokens, the transaction should revert.
        vm.expectRevert("ERC20LockableUpgradeable: insufficient unlocked balance");

        stableModProxy.transfer(bob, aliceLPBalanceBefore);

        // Skip some time to make the order executable.
        skip(orderAnnouncementModProxy.minExecutabilityAge() + 1);

        executeStableWithdraw({traderAccount: alice, keeperAccount: keeper, oraclePrice: 1000e8});
    }

    function test_revert_lock_when_called_by_unauthorized_address() public {
        setCollateralPrice(1000e8);

        // Execute a deposit to mint new flatcoins.
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 aliceLPBalance = stableModProxy.balanceOf(alice);

        vm.startPrank(carol);

        // Given that Carol is not an authorized address, the transaction should revert.
        vm.expectRevert(abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, carol));

        stableModProxy.lock(alice, aliceLPBalance);
    }

    function test_revert_unlock_when_called_by_unauthorized_address() public {
        setCollateralPrice(1000e8);

        // Execute a deposit to mint new flatcoins.
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 aliceLPBalance = stableModProxy.balanceOf(alice);

        // Announce redemption of a portion of the LP tokens.
        announceStableWithdraw({traderAccount: alice, withdrawAmount: aliceLPBalance, keeperFeeAmount: 0});

        vm.startPrank(carol);

        // Given that Carol is not an authorized address, the transaction should revert.
        vm.expectRevert(abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, carol));

        stableModProxy.unlock(alice, aliceLPBalance);
    }
}
