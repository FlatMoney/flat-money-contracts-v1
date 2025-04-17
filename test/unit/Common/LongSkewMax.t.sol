// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

contract LongSkewMaxTest is OrderHelpers, ExpectRevert {
    function test_long_skew_max_announce_leverage() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;
        uint256 margin = 100e18;
        uint256 sizeOk = 120e18; // skew fraction of 1.2
        uint256 sizeNok = 130e18; // skew fraction of 1.3, above configured max

        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: sizeOk,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // Opening bigger size over the max skew limit should revert
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceOpenLeverage.selector,
                alice,
                margin,
                sizeNok,
                keeperFee
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_announce_close_lp() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 120e18;
        uint256 margin = 120e18;
        uint256 size = 120e18;

        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // We can only remove 20e18 worth of stable LP before the system reaches the max skew limit.
        // Calculate the number of LP tokens to be burned to reach the max skew limit.
        uint256 lpTokensToBurn = (20e18 * 1e18) / stableModProxy.stableCollateralPerShare();

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: lpTokensToBurn,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // Closing any more of the stable LP should push the sytem over the max skew limit and it should revert
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceStableWithdraw.selector, alice, 1e18, keeperFee),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_execute_withdraw() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;
        uint256 margin = 100e18;
        uint256 size = 100e18;

        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 lpTokensToBurn = (15e18 * 1e18) / stableModProxy.stableCollateralPerShare();
        announceStableWithdraw({traderAccount: alice, withdrawAmount: lpTokensToBurn, keeperFeeAmount: keeperFee});

        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 15e18,
            additionalSize: 15e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        // Closing more stable LP makes the system reach the max skew limit and should revert
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.executeStableWithdraw.selector,
                keeper,
                alice,
                collateralPrice,
                false
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_execute_open() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;
        uint256 margin = 100e18;
        uint256 size = 100e18;

        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceOpenLeverage({traderAccount: bob, margin: 15e18, additionalSize: 15e18, keeperFeeAmount: keeperFee});

        uint256 lpTokensToBurn = (15e18 * 1e18) / stableModProxy.stableCollateralPerShare();

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: lpTokensToBurn,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        // Opening further leverage makes the system reach the max skew limit and should revert
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.executeOpenLeverage.selector,
                keeper,
                bob,
                collateralPrice,
                false
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_open_leverage_with_fee() public {
        // skewFractionMax is 120%
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        assertEq(skewFractionMax, 1.2e18);

        // Set leverage trade fee to 1%
        vm.prank(vaultProxy.owner());
        vaultProxy.setLeverageTradingFee(0.01e18);

        uint256 collateralPrice = 1000e8;

        uint256 depositAmount = 100e18;
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 additionalSize = 121.5e18;

        uint256 tradingFee = (additionalSize * vaultProxy.leverageTradingFee()) / 1e18;
        uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradingFee) / 1e18;

        uint256 expectedSkewPercent = (additionalSize * 1e18) / (depositAmount + tradingFee - protocolFee);

        // Check that the announce reverts on max skew
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceOpenLeverage.selector,
                alice,
                50e18,
                additionalSize,
                0
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });

        // Check that the execute reverts on max skew by first decreasing the skew with a stable deposit
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceOpenLeverage({traderAccount: alice, margin: 50e18, additionalSize: additionalSize, keeperFeeAmount: 0});

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(bob),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.executeOpenLeverage.selector, keeper, alice, collateralPrice),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });
    }

    function test_long_skew_max_adjust_leverage_with_fee() public {
        // skewFractionMax is 120%
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        assertEq(skewFractionMax, 1.2e18);

        // Set leverage trade fee to 1%
        vm.prank(vaultProxy.owner());
        vaultProxy.setLeverageTradingFee(0.01e18);

        uint256 collateralPrice = 1000e8;

        uint256 depositAmount = 100e18;
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 additionalSize = 100e18;
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 adjustSize = 21.5e18;
        uint256 tradingFee = ((additionalSize + adjustSize) * vaultProxy.leverageTradingFee()) / 1e18;
        uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradingFee) / 1e18;
        uint256 expectedSkewPercent = ((additionalSize + adjustSize) * 1e18) /
            (depositAmount + tradingFee - protocolFee);

        // Check that the announce reverts on max skew
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAdjustLeverage.selector,
                alice,
                tokenId,
                0,
                adjustSize,
                0
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });

        // Check that the execute reverts on max skew by first decreasing the skew with a stable deposit
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAdjustLeverage({
            tokenId: tokenId,
            traderAccount: alice,
            marginAdjustment: 0,
            additionalSizeAdjustment: int256(adjustSize),
            keeperFeeAmount: 0
        });

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(bob),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.executeAdjustLeverage.selector,
                keeper,
                alice,
                collateralPrice
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });
    }

    function test_long_skew_max_correct_skew_during_withdraw() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(_getLongSkewFraction(), 0, "Long skew fraction should be 0 before any leverage open");

        uint256 margin = 100e18;
        uint256 size = 100e18;

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            _getLongSkewFraction(),
            1e18,
            "Long skew fraction should be 1 after leverage open with size equal to stable deposit"
        );

        // We can only remove 20e18 worth of stable LP before the system reaches the max skew limit.
        // Calculate the number of LP tokens to be burned to reach the max skew limit.
        uint256 lpTokensToBurn = (20e18 * 1e18) / stableModProxy.stableCollateralPerShare();

        // Announcing withdraw of 20e18 worth of LP tokens should revert because it would push the system over the max skew limit (1.25 > 1.2)
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceStableWithdraw.selector, alice, lpTokensToBurn, 0),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_full_withdrawal() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;

        assertEq(vaultProxy.stableCollateralTotal(), 0);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(vaultProxy.stableCollateralTotal(), 0);
    }

    function test_long_skew_max_revert_when_no_stable_deposits() public {
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceOpenLeverage.selector, alice, 100e18, 100e18, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "stableCollateralTotal")
        });
    }

    function test_long_skew_max_withdraw_with_fee() public {
        // skewFractionMax is 120%
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        assertEq(skewFractionMax, 1.2e18);

        // withdraw fee is 1%
        vm.prank(vaultProxy.owner());
        vaultProxy.setStableWithdrawFee(0.01e18);

        uint256 collateralPrice = 1000e8;

        uint256 depositAmount = 100e18;
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 additionalSize = 100e18;
        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Alice withdraws 19.9e18 worth of stable LP tokens.
        uint256 withdrawAmount = (19.9e18 * 1e18) / stableModProxy.stableCollateralPerShare();
        uint256 expectedSkewPercent;
        {
            uint256 withdrawAmountInCollateral = 19.9e18;
            uint256 withdrawFee = (withdrawAmountInCollateral * vaultProxy.stableWithdrawFee()) / 1e18;
            uint256 protocolFee = (vaultProxy.protocolFeePercentage() * withdrawFee) / 1e18;

            expectedSkewPercent =
                (additionalSize * 1e18) /
                (depositAmount - withdrawAmountInCollateral + (withdrawFee - protocolFee));
        }

        // Check that the announce reverts on max skew
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceStableWithdraw.selector, alice, withdrawAmount, 0),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });

        // Check that the execute reverts on max skew by first decreasing the skew with a stable deposit
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceStableWithdraw({traderAccount: alice, withdrawAmount: withdrawAmount, keeperFeeAmount: 0});

        // Temporarily disable withdraw fee
        vm.prank(vaultProxy.owner());
        vaultProxy.setStableWithdrawFee(0);

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(bob),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Set withdraw fee to 1% again
        vm.prank(vaultProxy.owner());
        vaultProxy.setStableWithdrawFee(0.01e18);

        // Execute should revert with the same skew
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.executeStableWithdraw.selector,
                keeper,
                alice,
                collateralPrice
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.MaxSkewReached.selector, expectedSkewPercent)
        });
    }

    // Internal helper functions

    function _getLongSkewFraction() internal view returns (uint256 longSkewFraction) {
        longSkewFraction =
            (vaultProxy.getGlobalPositions().sizeOpenedTotal * 1e18) /
            vaultProxy.stableCollateralTotal();
    }
}
