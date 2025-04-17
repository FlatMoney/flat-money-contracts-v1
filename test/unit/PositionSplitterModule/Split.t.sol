// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import {IPositionSplitterModule} from "../../../src/interfaces/IPositionSplitterModule.sol";

contract PositionSplitterTest is OrderHelpers {
    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        // Enable funding rate.
        controllerModProxy.setMaxFundingVelocity(0.03e18);
    }

    function test_split() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(1 days);

        LeverageModuleStructs.Position memory primaryPositionBefore = vaultProxy.getPosition(primaryTokenId);
        LeverageModuleStructs.PositionSummary memory primaryPositionSummaryBefore = leverageModProxy.getPositionSummary(
            primaryTokenId
        );

        vm.startPrank(alice);

        // Equivalent to 20% of the primary position's margin deposited or 5 ETH of original marginDeposited.
        uint256 newTokenId = positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);

        LeverageModuleStructs.Position memory newPosition = vaultProxy.getPosition(newTokenId);
        LeverageModuleStructs.Position memory primaryPositionAfter = vaultProxy.getPosition(primaryTokenId);

        assertEq(primaryPositionAfter.marginDeposited, 20e18, "Primary position's margin deposited is incorrect");
        assertEq(primaryPositionAfter.additionalSize, 40e18, "Primary position's additional size is incorrect");
        assertEq(
            ((primaryPositionAfter.marginDeposited + primaryPositionAfter.additionalSize) * 1e18) /
                primaryPositionAfter.marginDeposited,
            3e18,
            "Primary position's leverage ratio is incorrect"
        );
        assertEq(
            ((newPosition.marginDeposited + newPosition.additionalSize) * 1e18) / newPosition.marginDeposited,
            3e18,
            "New position's leverage ratio is incorrect"
        );
        assertEq(
            primaryPositionAfter.averagePrice,
            primaryPositionBefore.averagePrice,
            "Primary position's average price is incorrect"
        );
        assertEq(
            primaryPositionAfter.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "Primary position's entry cumulative funding is incorrect"
        );
        assertEq(leverageModProxy.ownerOf(newTokenId), bob, "New position's owner is incorrect");
        assertEq(newPosition.marginDeposited, 5e18, "New position's margin deposited is incorrect");
        assertEq(newPosition.additionalSize, 10e18, "New position's additional size is incorrect");
        assertEq(
            newPosition.averagePrice,
            primaryPositionBefore.averagePrice,
            "New position's average price is incorrect"
        );
        assertEq(
            newPosition.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "New position's entry cumulative funding is incorrect"
        );
        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            primaryPositionSummaryBefore.marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement"
        );
    }

    function test_split_with_uneven_leverage_ratio() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 45.25e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(1 days);

        LeverageModuleStructs.Position memory primaryPositionBefore = vaultProxy.getPosition(primaryTokenId);
        LeverageModuleStructs.PositionSummary memory primaryPositionSummaryBefore = leverageModProxy.getPositionSummary(
            primaryTokenId
        );

        vm.startPrank(alice);

        // Equivalent to 20% of the primary position's margin deposited or 5 ETH of original marginDeposited.
        uint256 newTokenId = positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);

        LeverageModuleStructs.Position memory newPosition = vaultProxy.getPosition(newTokenId);
        LeverageModuleStructs.Position memory primaryPositionAfter = vaultProxy.getPosition(primaryTokenId);

        assertEq(primaryPositionAfter.marginDeposited, 20e18, "Primary position's margin deposited is incorrect");
        assertEq(primaryPositionAfter.additionalSize, 36.2e18, "Primary position's additional size is incorrect");
        assertEq(
            ((primaryPositionAfter.marginDeposited + primaryPositionAfter.additionalSize) * 1e18) /
                primaryPositionAfter.marginDeposited,
            2.81e18,
            "Primary position's leverage ratio is incorrect"
        );
        assertEq(
            ((newPosition.marginDeposited + newPosition.additionalSize) * 1e18) / newPosition.marginDeposited,
            2.81e18,
            "New position's leverage ratio is incorrect"
        );
        assertEq(
            primaryPositionAfter.averagePrice,
            primaryPositionBefore.averagePrice,
            "Primary position's average price is incorrect"
        );
        assertEq(
            primaryPositionAfter.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "Primary position's entry cumulative funding is incorrect"
        );
        assertEq(leverageModProxy.ownerOf(newTokenId), bob, "New position's owner is incorrect");
        assertEq(newPosition.marginDeposited, 5e18, "New position's margin deposited is incorrect");
        assertEq(newPosition.additionalSize, 9.05e18, "New position's additional size is incorrect");
        assertEq(
            newPosition.averagePrice,
            primaryPositionBefore.averagePrice,
            "New position's average price is incorrect"
        );
        assertEq(
            newPosition.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "New position's entry cumulative funding is incorrect"
        );
        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            primaryPositionSummaryBefore.marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement"
        );
    }

    function test_split_after_price_increase() public {
        setCollateralPrice(1000e8);

        // Disable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 primaryTokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 duplicateTokenId = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        skip(1 days);

        setCollateralPrice(2000e8);

        LeverageModuleStructs.Position memory primaryPositionBefore = vaultProxy.getPosition(primaryTokenId);
        LeverageModuleStructs.PositionSummary memory primaryPositionSummaryBefore = leverageModProxy.getPositionSummary(
            primaryTokenId
        );

        vm.startPrank(alice);
        uint256 newTokenId = positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);

        LeverageModuleStructs.Position memory newPosition = vaultProxy.getPosition(newTokenId);
        LeverageModuleStructs.Position memory primaryPositionAfter = vaultProxy.getPosition(primaryTokenId);

        assertEq(primaryPositionAfter.marginDeposited, 20e18, "Primary position's margin deposited is incorrect");
        assertEq(primaryPositionAfter.additionalSize, 40e18, "Primary position's additional size is incorrect");
        assertEq(
            ((primaryPositionAfter.marginDeposited + primaryPositionAfter.additionalSize) * 1e18) /
                primaryPositionAfter.marginDeposited,
            3e18,
            "Primary position's leverage ratio is incorrect"
        );
        assertEq(
            ((newPosition.marginDeposited + newPosition.additionalSize) * 1e18) / newPosition.marginDeposited,
            3e18,
            "New position's leverage ratio is incorrect"
        );
        assertEq(
            primaryPositionAfter.averagePrice,
            primaryPositionBefore.averagePrice,
            "Primary position's average price is incorrect"
        );
        assertEq(
            primaryPositionAfter.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "Primary position's entry cumulative funding is incorrect"
        );
        assertEq(leverageModProxy.ownerOf(newTokenId), bob, "New position's owner is incorrect");
        assertEq(newPosition.marginDeposited, 5e18, "New position's margin deposited is incorrect");
        assertEq(newPosition.additionalSize, 10e18, "New position's additional size is incorrect");
        assertEq(
            newPosition.averagePrice,
            primaryPositionBefore.averagePrice,
            "New position's average price is incorrect"
        );
        assertEq(
            newPosition.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "New position's entry cumulative funding is incorrect"
        );
        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            primaryPositionSummaryBefore.marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement"
        );

        skip(10 days);

        setCollateralPrice(3000e8);

        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            leverageModProxy.getPositionSummary(duplicateTokenId).marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement after price increase"
        );
    }

    function test_split_after_price_decrease() public {
        setCollateralPrice(1000e8);

        // Disable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 primaryTokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 duplicateTokenId = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        skip(1 days);

        setCollateralPrice(900e8);

        LeverageModuleStructs.Position memory primaryPositionBefore = vaultProxy.getPosition(primaryTokenId);
        LeverageModuleStructs.PositionSummary memory primaryPositionSummaryBefore = leverageModProxy.getPositionSummary(
            primaryTokenId
        );

        vm.startPrank(alice);
        uint256 newTokenId = positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);

        LeverageModuleStructs.Position memory newPosition = vaultProxy.getPosition(newTokenId);
        LeverageModuleStructs.Position memory primaryPositionAfter = vaultProxy.getPosition(primaryTokenId);

        assertEq(primaryPositionAfter.marginDeposited, 20e18, "Primary position's margin deposited is incorrect");
        assertEq(primaryPositionAfter.additionalSize, 40e18, "Primary position's additional size is incorrect");
        assertEq(
            ((primaryPositionAfter.marginDeposited + primaryPositionAfter.additionalSize) * 1e18) /
                primaryPositionAfter.marginDeposited,
            3e18,
            "Primary position's leverage ratio is incorrect"
        );
        assertEq(
            ((newPosition.marginDeposited + newPosition.additionalSize) * 1e18) / newPosition.marginDeposited,
            3e18,
            "New position's leverage ratio is incorrect"
        );
        assertEq(
            primaryPositionAfter.averagePrice,
            primaryPositionBefore.averagePrice,
            "Primary position's average price is incorrect"
        );
        assertEq(
            primaryPositionAfter.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "Primary position's entry cumulative funding is incorrect"
        );
        assertEq(leverageModProxy.ownerOf(newTokenId), bob, "New position's owner is incorrect");
        assertEq(newPosition.marginDeposited, 5e18, "New position's margin deposited is incorrect");
        assertEq(newPosition.additionalSize, 10e18, "New position's additional size is incorrect");
        assertEq(
            newPosition.averagePrice,
            primaryPositionBefore.averagePrice,
            "New position's average price is incorrect"
        );
        assertEq(
            newPosition.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "New position's entry cumulative funding is incorrect"
        );
        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            primaryPositionSummaryBefore.marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement"
        );

        skip(10 days);

        setCollateralPrice(800e8);

        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            leverageModProxy.getPositionSummary(duplicateTokenId).marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement after price decrease"
        );
    }

    /// @dev We want to check that the margin after settlement of the new positions is equal to the margin after settlement
    ///      of the original primary position.
    function test_split_after_price_decrease_followed_by_price_increase() public {
        setCollateralPrice(1000e8);

        // Disable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 primaryTokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 duplicateTokenId = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enable funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        skip(1 days);

        setCollateralPrice(900e8);

        LeverageModuleStructs.Position memory primaryPositionBefore = vaultProxy.getPosition(primaryTokenId);
        LeverageModuleStructs.PositionSummary memory primaryPositionSummaryBefore = leverageModProxy.getPositionSummary(
            primaryTokenId
        );

        vm.startPrank(alice);
        uint256 newTokenId = positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);

        LeverageModuleStructs.Position memory newPosition = vaultProxy.getPosition(newTokenId);
        LeverageModuleStructs.Position memory primaryPositionAfter = vaultProxy.getPosition(primaryTokenId);

        assertEq(primaryPositionAfter.marginDeposited, 20e18, "Primary position's margin deposited is incorrect");
        assertEq(primaryPositionAfter.additionalSize, 40e18, "Primary position's additional size is incorrect");
        assertEq(
            ((primaryPositionAfter.marginDeposited + primaryPositionAfter.additionalSize) * 1e18) /
                primaryPositionAfter.marginDeposited,
            3e18,
            "Primary position's leverage ratio is incorrect"
        );
        assertEq(
            ((newPosition.marginDeposited + newPosition.additionalSize) * 1e18) / newPosition.marginDeposited,
            3e18,
            "New position's leverage ratio is incorrect"
        );
        assertEq(
            primaryPositionAfter.averagePrice,
            primaryPositionBefore.averagePrice,
            "Primary position's average price is incorrect"
        );
        assertEq(
            primaryPositionAfter.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "Primary position's entry cumulative funding is incorrect"
        );
        assertEq(leverageModProxy.ownerOf(newTokenId), bob, "New position's owner is incorrect");
        assertEq(newPosition.marginDeposited, 5e18, "New position's margin deposited is incorrect");
        assertEq(newPosition.additionalSize, 10e18, "New position's additional size is incorrect");
        assertEq(
            newPosition.averagePrice,
            primaryPositionBefore.averagePrice,
            "New position's average price is incorrect"
        );
        assertEq(
            newPosition.entryCumulativeFunding,
            primaryPositionBefore.entryCumulativeFunding,
            "New position's entry cumulative funding is incorrect"
        );
        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            primaryPositionSummaryBefore.marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement"
        );

        skip(10 days);

        setCollateralPrice(1100e8);

        assertApproxEqAbs(
            leverageModProxy.getPositionSummary(newTokenId).marginAfterSettlement +
                leverageModProxy.getPositionSummary(primaryTokenId).marginAfterSettlement,
            leverageModProxy.getPositionSummary(duplicateTokenId).marginAfterSettlement,
            1e6, // Accounting for rounding errors
            "Sum of new positions' margin after settlement should equal original primary position's margin after settlement after price increase"
        );
    }

    function test_revert_split_not_owner_of_primary_position() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(PositionSplitterModule.OnlyPositionOwner.selector, alice));
        positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);
    }

    function test_revert_split_when_primary_position_is_liquidatable_before_split() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice((viewer.liquidationPrice(primaryTokenId) - 1e18) / 1e10);

        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(PositionSplitterModule.PrimaryPositionLiquidatable.selector, primaryTokenId)
        );

        positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);
    }

    function test_revert_split_when_newly_created_position_liquidatable() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice((viewer.liquidationPrice(primaryTokenId) + 2e18) / 1e10);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(PositionSplitterModule.NewPositionLiquidatable.selector, 1));

        // Equivalent to splitting a position such that the new position has 0.1 ether `marginDeposited`.
        positionSplitterProxy.split(primaryTokenId, 0.004e18, bob);
    }

    function test_revert_split_when_modified_primary_position_liquidatable_after_split() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 50e18, // 3x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // The modified primary position has a leverage ratio of 3x and average price of 1000e18.
        // It's liquidation price is approx 666e18. So this position is liquidatable at 550e18.
        setCollateralPrice((viewer.liquidationPrice(primaryTokenId) + 2e18) / 1e10);

        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(PositionSplitterModule.PrimaryPositionLiquidatable.selector, primaryTokenId)
        );

        // Equivalent to splitting a position such that the new position has 24.9 ether `marginDeposited`.
        positionSplitterProxy.split(primaryTokenId, 0.996e18, bob);
    }

    function test_revert_split_when_limit_order_exists() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: primaryTokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LimitClose)
        );

        positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);
    }

    function test_revert_split_when_a_delayed_order_announced() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: primaryTokenId,
            marginAdjustment: -5e18,
            additionalSizeAdjustment: -5e18,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.OrderExists.selector, DelayedOrderStructs.OrderType.LeverageAdjust)
        );

        positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);
    }

    function test_revert_split_when_new_position_is_the_same_as_primary_position() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        // Technically there is no explicit check preventing this scenario. However,
        // the new position shouldn't be created due to the leverage criteria check.
        // This check reverts due to division by zero.
        vm.expectRevert();

        positionSplitterProxy.split(primaryTokenId, 1e18, bob);
    }

    function test_revert_split_when_paused() public {
        setCollateralPrice(1000e8);

        uint256 primaryTokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 25e18,
            additionalSize: 25e18, // 2x leverage
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        bytes32 moduleKey = positionSplitterProxy.MODULE_KEY();

        vm.startPrank(admin);
        vaultProxy.pauseModule(moduleKey);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, moduleKey));

        positionSplitterProxy.split(primaryTokenId, 0.2e18, bob);
    }
}
