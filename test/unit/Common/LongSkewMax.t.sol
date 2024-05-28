// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinStructs} from "src/libraries/FlatcoinStructs.sol";
import {FlatcoinErrors} from "src/libraries/FlatcoinErrors.sol";

import "forge-std/console2.sol";

contract LongSkewMaxTest is Setup, OrderHelpers, ExpectRevert {
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

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: 20e18,
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

        announceStableWithdraw({traderAccount: alice, withdrawAmount: 15e18, keeperFeeAmount: keeperFee});

        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 15e18,
            additionalSize: 15e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        skip(uint256(vaultProxy.minExecutabilityAge())); // must reach minimum executability time

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

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: 15e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        skip(uint256(vaultProxy.minExecutabilityAge())); // must reach minimum executability time

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
        leverageModProxy.setLeverageTradingFee(0.01e18);

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

        uint256 expectedSkewPercent = (additionalSize * 1e18) /
            (depositAmount + ((additionalSize * leverageModProxy.leverageTradingFee()) / 1e18));

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
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
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
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
        });
    }

    function test_long_skew_max_adjust_leverage_with_fee() public {
        // skewFractionMax is 120%
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        assertEq(skewFractionMax, 1.2e18);

        // Set leverage trade fee to 1%
        vm.prank(vaultProxy.owner());
        leverageModProxy.setLeverageTradingFee(0.01e18);

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

        uint256 expectedSkewPercent = ((additionalSize + adjustSize) * 1e18) /
            (depositAmount + (((additionalSize + adjustSize) * leverageModProxy.leverageTradingFee()) / 1e18));

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
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
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
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
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

        // Announcing withdraw of 20e18 should revert because it would push the system over the max skew limit (1.25 > 1.2)
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceStableWithdraw.selector, alice, 20e18, 0),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_long_skew_max_full_withdrawal() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 100e18;

        assertEq(vaultProxy.getVaultSummary().stableCollateralTotal, 0);

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
            withdrawAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(vaultProxy.getVaultSummary().stableCollateralTotal, 0);
    }

    function test_long_skew_max_revert_when_no_stable_deposits() public {
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceOpenLeverage.selector, alice, 100e18, 100e18, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.ZeroValue.selector, "stableCollateralTotal")
        });
    }

    function test_long_skew_max_withdraw_with_fee() public {
        // skewFractionMax is 120%
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        assertEq(skewFractionMax, 1.2e18);

        // withdraw fee is 1%
        vm.prank(vaultProxy.owner());
        stableModProxy.setStableWithdrawFee(0.01e18);

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

        // Alice withdraws 19.9 collateral
        uint256 withdrawAmount = 19.9e18;
        uint256 expectedSkewPercent = (additionalSize * 1e18) /
            (depositAmount - withdrawAmount + ((withdrawAmount * stableModProxy.stableWithdrawFee()) / 1e18));

        // Check that the announce reverts on max skew
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceStableWithdraw.selector, alice, 19.9e18, 0),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
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
        stableModProxy.setStableWithdrawFee(0);

        announceAndExecuteWithdraw({
            traderAccount: bob,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(bob),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Set withdraw fee to 1% again
        vm.prank(vaultProxy.owner());
        stableModProxy.setStableWithdrawFee(0.01e18);

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
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxSkewReached.selector, expectedSkewPercent)
        });
    }

    // Internal helper functions

    function _getLongSkewFraction() internal view returns (uint256 longSkewFraction) {
        longSkewFraction =
            (vaultProxy.getGlobalPositions().sizeOpenedTotal * 1e18) /
            vaultProxy.stableCollateralTotal();
    }
}
