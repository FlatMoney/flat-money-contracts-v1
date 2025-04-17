// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {DecimalMath} from "../../../src/libraries/DecimalMath.sol";

import "../../helpers/OrderHelpers.sol";

contract LiquidateTest is OrderHelpers {
    using DecimalMath for int256;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.003e18);

        disableChainlinkExpiry();
    }

    // NOTE: Once `liquidate(uint256 tokenId, bytes[] calldata priceUpdateData)` is deprecated, remove this test.
    function test_liquidate_single_position_with_price_update() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin and 3x leverage.
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(0);

        setCollateralPrice((liqPrice - 1e18) / 1e10);
        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position should be liquidatable");

        vm.startPrank(liquidator);

        bytes[] memory priceUpdateData = getPriceUpdateData((liqPrice - 1e18) / 1e10);
        liquidationModProxy.liquidate{value: 2}(tokenId, priceUpdateData);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);

        assertEq(position.marginDeposited, 0, "Position should have been deleted");
    }

    // NOTE: Once `liquidate(uint256 tokenId)` is deprecated, remove this test.
    function test_liquidate_single_position_without_price_update() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin and 3x leverage.
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(0);

        setCollateralPrice((liqPrice - 1e18) / 1e10);
        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position should be liquidatable");

        vm.startPrank(liquidator);

        liquidationModProxy.liquidate(tokenId);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);

        assertEq(position.marginDeposited, 0, "Position should have been deleted");
    }

    function test_liquidation_when_price_decrease_but_position_not_liquidatable() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin and 3x leverage.
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(0);

        // Price goes down to within $10 of the liquidation price.
        setCollateralPrice((liqPrice + 10e18) / 1e10);

        assertFalse(liquidationModProxy.canLiquidate(0), "Leverage position should not be liquidatable");

        vm.startPrank(liquidator);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory liquidatedIDs = liquidationModProxy.liquidate(tokenIds);
        assertTrue(liquidatedIDs.length == 0, "Liquidation should have failed");
    }

    function test_liquidation_when_price_decrease_but_position_not_liquidatable_due_to_funding() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin and 2x leverage.
        // The market is skewed towards LP.
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(15 days);

        uint256 liqPriceAfter = viewer.liquidationPrice(0);

        assertLt(liqPriceAfter, liqPriceBefore, "Liquidation price should have decreased");

        // Set the price of collateralAsset  to be the earlier liquidation price.
        setCollateralPrice(liqPriceBefore / 1e10);

        assertFalse(liquidationModProxy.canLiquidate(0), "Leverage position should not be liquidatable");

        vm.startPrank(liquidator);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory liquidatedIDs = liquidationModProxy.liquidate(tokenIds);
        assertTrue(liquidatedIDs.length == 0, "Liquidation should have failed");
    }

    function test_liquidation_when_price_increases_and_position_not_liquidatable() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin and 3x leverage.
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        // Price goes up by 20%.
        setCollateralPrice(1200e8);

        assertFalse(liquidationModProxy.canLiquidate(0), "Leverage position should not be liquidatable");

        vm.startPrank(liquidator);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory liquidatedIDs = liquidationModProxy.liquidate(tokenIds);
        assertTrue(liquidatedIDs.length == 0, "Liquidation should have failed");
    }

    // The test checks that funding rates are taken into account when checking if a position is liquidatable or not.
    function test_liquidation_when_price_increase_but_position_liquidatable_due_to_funding() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 60e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.006e18);
        controllerModProxy.setMaxVelocitySkew(0.2e18);

        // Note that the amount of days to be skipped has been chosen arbitrarily.
        // The higher the number of days skipped, the higher the funding rate.
        // This means, in this particular scenario, longs are paying LPs so much so that their
        // profits are offset by the funding fees.
        skip(15 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        assertGt(liqPrice / 1e10, 1000e8, "Liquidation price should be greater than entry price");

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setCollateralPrice((liqPrice - 1e18) / 1e10);

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();
        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );
        uint256 liquidationFee = liquidationModProxy.getLiquidationFee(tokenId);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
        assertGt(
            alicePositionSummary.marginAfterSettlement,
            0,
            "Position must not be underwater (not negative margin)"
        );
        assertGt(
            uint256(alicePositionSummary.marginAfterSettlement),
            liquidationFee,
            "Remaining margin should be higher than liquidation fee"
        );

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();
        uint256 remainingMargin = (uint256(alicePositionSummary.marginAfterSettlement) > liquidationFee)
            ? uint256(alicePositionSummary.marginAfterSettlement) - liquidationFee
            : 0;

        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            liquidationFee,
            "Liquidator fee not awarded correctly"
        );

        // Note that we are subtracting the funding fees from the remaining margin on the RHS because a call to `liquidate`
        // function will settle the funding fees before actually liquidating a position.
        // Why subtract instead of add? This is because the funding fees are negative in this case indicating that
        // the longs are paying the LPs (so -ve of -ve is +ve). After settlement, the LPs will receive this amount.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            int256(remainingMargin) - alicePositionSummary.profitLoss - marketSummary.accruedFundingTotalByLongs,
            1,
            "Alice's remaining margin should be given to the LPs"
        );

        // The position should not exist in the `_positions` mapping.
        assertTrue(vaultProxy.getPosition(tokenId).marginDeposited == 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );

        FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

        assertEq(
            int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
            int256(collateralAsset.balanceOf(address(vaultProxy))),
            "Vault balance incorrect"
        );
    }

    /// @notice Tests accounting when the liquidator fee is lower than usual because the position is close to the liquidation price.
    function test_liquidation_lower_liquidator_fee() public {
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

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        setCollateralPrice((liqPrice - 2.1e18) / 1e10); // liquidator fee will be lower than regular fee

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );
        int256 remainingMargin = alicePositionSummary.marginAfterSettlement;
        int256 profitLoss = alicePositionSummary.profitLoss;

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
        assertGt(
            alicePositionSummary.marginAfterSettlement,
            0,
            "Position must not be underwater (not negative margin)"
        );
        assertLt(
            uint256(alicePositionSummary.marginAfterSettlement),
            liquidationModProxy.getLiquidationFee(tokenId),
            "Remaining margin should be lower than liquidation fee"
        );

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();
        uint256 liquidatorFee = liquidatorBalanceAfter - liquidatorBalanceBefore;

        assertGt(liquidatorFee, 0, "Liquidator fee should have been awarded");
        assertEq(int256(liquidatorFee), remainingMargin, "Liquidator fee should be the same as margin");
        assertEq(vaultProxy.getPosition(tokenId).marginDeposited, 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );
        assertApproxEqAbs(
            int256(stableCollateralTotalBefore),
            int256(stableCollateralTotalAfter) + profitLoss,
            1,
            "Incorrect stable collateral total"
        );
    }

    // Test to check that liquidations are working as expected even in the case of a position
    // being underwater (bad debt).
    function test_liquidation_when_position_underwater_due_to_price_decrease() public {
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

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        setCollateralPrice((liqPrice - 50e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();
        int256 fundingAdjustedPnlTotalBefore = controllerModProxy.fundingAdjustedLongPnLTotal({
            maxAge_: type(uint32).max,
            priceDiffCheck_: false
        });

        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );

        assertLt(alicePositionSummary.marginAfterSettlement, 0, "Position should be underwater");

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();

        assertEq(liquidatorBalanceAfter, liquidatorBalanceBefore, "Liquidator fee should not have been awarded");

        // Note that funding fees play no role here as the market was perfectly hedged.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            alicePositionSummary.marginAfterSettlement - fundingAdjustedPnlTotalBefore,
            1,
            "Stable collateral total after liquidation incorrect"
        );
        assertEq(vaultProxy.getPosition(tokenId).marginDeposited, 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            // Total collateral in the vault is the sum of the stable collateral and the margin deposited.
            // Note that we are not adding or subtracting the funding fees given that settlement of the same
            // is accounted for already in the `stableCollateralTotal` or `marginDepositedTotal` variables
            // in the `settleFundingFees` function in the vault contract.
            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }
    }

    // Test to check that liquidations are working as expected even in the case of a position
    // being underwater (bad debt).
    function test_liquidation_when_position_underwater_due_to_funding_fees_payment() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 60e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.006e18);
        controllerModProxy.setMaxVelocitySkew(0.2e18);

        // Note that the amount of days to be skipped has been chosen arbitrarily.
        skip(15 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        setCollateralPrice((liqPrice - 50e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();
        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );

        assertLt(alicePositionSummary.marginAfterSettlement, 0, "Position should be underwater");

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();

        assertEq(liquidatorBalanceAfter, liquidatorBalanceBefore, "Liquidator fee should not have been awarded");
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            alicePositionSummary.marginAfterSettlement -
                alicePositionSummary.profitLoss -
                marketSummary.accruedFundingTotalByLongs,
            1,
            "Stable collateral total after liquidation incorrect"
        );

        assertEq(vaultProxy.getPosition(tokenId).marginDeposited, 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );

        FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

        // Total collateral in the vault is the sum of the stable collateral and the margin deposited.
        // Note that we are not adding or subtracting the funding fees given that settlement of the same
        // is accounted for already in the `stableCollateralTotal` or `marginDepositedTotal` variables
        // in the `settleFundingFees` function in the vault contract.
        assertEq(
            int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
            int256(collateralAsset.balanceOf(address(vaultProxy))),
            "Vault balance incorrect"
        );
    }

    function test_liquidation_underwater_stable_collateral_settle() public {
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 12e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdAlice = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 3e18,
            additionalSize: 6e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 5e18,
            additionalSize: 6e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(600e8);

        vm.startPrank(liquidator);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenIdAlice;
        liquidationModProxy.liquidate(tokenIds); // Triggers updateGlobalPositionData

        // triggers another updateGlobalPositionData
        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 0.05e18,
            additionalSize: 0.05e18,
            oraclePrice: 600e8,
            keeperFeeAmount: 0
        });

        // Alice's deposited margin should be transfered to stable LPs
        assertEq(vaultProxy.stableCollateralTotal(), 15e18, "Incorrect stable collateral total after settlement");
    }

    function test_liquidation_using_price_update_data() public {
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

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(0);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setCollateralPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );
        uint256 liquidationFee = liquidationModProxy.getLiquidationFee(tokenId);

        vm.startPrank(liquidator);
        // Since the next function call updates Pyth price, we need to skip at least 1 second
        // for it to be updated.
        skip(1);
        // Should not be liquidatable (just above liquidation price)
        bytes[] memory priceUpdateData = getPriceUpdateData((liqPrice + 1e18) / 1e10);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory liquidatedIDs = liquidationModProxy.liquidate{value: 2}(tokenIds, priceUpdateData);
        assertTrue(liquidatedIDs.length == 0, "Liquidation should have failed");

        // Should be liquidatable (just below liquidation price)
        skip(1);
        liquidationModProxy.liquidate{value: 2}(tokenIds, getPriceUpdateData((liqPrice - 1e18) / 1e10));

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();
        uint256 remainingMargin = (uint256(alicePositionSummary.marginAfterSettlement) > liquidationFee)
            ? uint256(alicePositionSummary.marginAfterSettlement) - liquidationFee
            : 0;

        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            liquidationFee,
            "Liquidator fee not awarded correctly"
        );

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }

        // Note: We are not taking into account the settled funding fees as this test won't produce any.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            int256(remainingMargin) - alicePositionSummary.profitLoss,
            1,
            "Alice's margin should be given to the LPs"
        );

        // The position should not exist in the `_positions` mapping.
        assertTrue(vaultProxy.getPosition(tokenId).marginDeposited == 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );
    }

    function test_liquidate_multiple_position_all_either_liquidatable_or_not() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 50e18,
            margin: 25e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 50e18,
            margin: 25e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        // Liquidation price for both positions should be the same given they are of the same leverage ratio.
        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setCollateralPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position 1 should be liquidatable");
        assertTrue(liquidationModProxy.canLiquidate(tokenId2), "Leverage position 2 should be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        uint256 liquidationFee;
        int256 remainingMargin;
        {
            LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.PositionSummary memory bobPositionSummary = leverageModProxy.getPositionSummary(
                tokenId2
            );

            uint256 liquidationFee1 = liquidationModProxy.getLiquidationFee(tokenId);
            uint256 liquidationFee2 = liquidationModProxy.getLiquidationFee(tokenId2);
            liquidationFee = liquidationFee1 + liquidationFee2;

            uint256 remainingMargin1 = (uint256(alicePositionSummary.marginAfterSettlement) > liquidationFee1)
                ? uint256(alicePositionSummary.marginAfterSettlement) - liquidationFee1
                : 0;
            uint256 remainingMargin2 = (uint256(bobPositionSummary.marginAfterSettlement) > liquidationFee2)
                ? uint256(bobPositionSummary.marginAfterSettlement) - liquidationFee2
                : 0;

            remainingMargin =
                int256(remainingMargin1 + remainingMargin2) -
                (alicePositionSummary.profitLoss + bobPositionSummary.profitLoss);
        }

        vm.startPrank(liquidator);

        // Since the next function call updates Pyth price, we need to skip at least 1 second
        // for it to be updated.
        skip(1);
        {
            // Should not be liquidatable (just above liquidation price)
            uint256[] memory tokenIds = new uint256[](2);
            tokenIds[0] = tokenId;
            tokenIds[1] = tokenId2;

            uint256[] memory liquidatedIDs = liquidationModProxy.liquidate{value: 2}(
                tokenIds,
                getPriceUpdateData((liqPrice + 1e18) / 1e10)
            );

            assertTrue(liquidatedIDs.length == 0, "Liquidation of positions should have failed");

            // Should be liquidatable (just below liquidation price)
            skip(1);
            liquidatedIDs = liquidationModProxy.liquidate{value: 2}(
                tokenIds,
                getPriceUpdateData((liqPrice - 1e18) / 1e10)
            );

            assertTrue(liquidatedIDs[0] == tokenId, "Liquidation of position 1 should have succeeded");
            assertTrue(liquidatedIDs[1] == tokenId2, "Liquidation of position 2 should have succeeded");
        }

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();

        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            liquidationFee,
            "Liquidator fee not awarded correctly"
        );

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }

        // Note: We are not taking into account the settled funding fees as this test won't produce any.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            int256(remainingMargin),
            1,
            "Alice's margin should be given to the LPs"
        );

        // The position should not exist in the `_positions` mapping.
        assertTrue(vaultProxy.getPosition(tokenId).marginDeposited == 0, "Position should have been deleted");
        assertTrue(vaultProxy.getPosition(tokenId2).marginDeposited == 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );
    }

    function test_liquidate_multiple_position_some_non_liquidatable() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 50e18,
            margin: 25e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 50e18,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        // Liquidation price for both positions should be the same given they are of the same leverage ratio.
        uint256 liqPrice = viewer.liquidationPrice(tokenId);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setCollateralPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position 1 should be liquidatable");
        assertFalse(liquidationModProxy.canLiquidate(tokenId2), "Leverage position 2 should not be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        uint256 liquidationFee;
        int256 remainingMargin;
        {
            LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
                tokenId
            );

            liquidationFee = liquidationModProxy.getLiquidationFee(tokenId);
            uint256 remainingMargin1 = (uint256(alicePositionSummary.marginAfterSettlement) > liquidationFee)
                ? uint256(alicePositionSummary.marginAfterSettlement) - liquidationFee
                : 0;

            remainingMargin = int256(remainingMargin1) - alicePositionSummary.profitLoss;
        }

        vm.startPrank(liquidator);

        // Since the next function call updates Pyth price, we need to skip at least 1 second
        // for it to be updated.
        skip(1);
        {
            // Should not be liquidatable (just above liquidation price)
            uint256[] memory tokenIds = new uint256[](2);
            tokenIds[0] = tokenId;
            tokenIds[1] = tokenId2;

            uint256[] memory liquidatedIDs = liquidationModProxy.liquidate{value: 2}(
                tokenIds,
                getPriceUpdateData((liqPrice + 1e18) / 1e10)
            );

            assertTrue(liquidatedIDs.length == 0, "Liquidation of positions should have failed");

            // Should be liquidatable (just below liquidation price)
            skip(1);
            liquidatedIDs = liquidationModProxy.liquidate{value: 2}(
                tokenIds,
                getPriceUpdateData((liqPrice - 1e18) / 1e10)
            );

            assertTrue(
                liquidatedIDs.length == 1 && liquidatedIDs[0] == tokenId,
                "Liquidation of position 1 should have succeeded and position 2 should have failed"
            );
        }

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();

        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            liquidationFee,
            "Liquidator fee not awarded correctly"
        );

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }

        // Note: We are not taking into account the settled funding fees as this test won't produce any.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            int256(remainingMargin),
            1,
            "Alice's margin should be given to the LPs"
        );

        // The position should not exist in the `_positions` mapping.
        assertTrue(vaultProxy.getPosition(tokenId).marginDeposited == 0, "Position should have been deleted");
        assertFalse(vaultProxy.getPosition(tokenId2).marginDeposited == 0, "Position should not have been deleted");
    }

    function test_liquidate_when_liquidationFee_within_bounds() public {
        setCollateralPrice(1000e8);

        // Increase fee bound for more accurate liquidation price approximation.
        liquidationModProxy.setLiquidationFeeBounds({
            newLiquidationFeeLowerBound_: 4e18,
            newLiquidationFeeUpperBound_: 10_000e18
        });

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(0);

        // Check the liquidation price precisely in this test
        // By setting the price just above liquidation price, the position should not be liquidatable.
        setCollateralPrice((liqPrice + 1e10) / 1e10);
        assertFalse(liquidationModProxy.canLiquidate(tokenId), "Leverage position should not be liquidatable");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory liquidatedIDs = liquidationModProxy.liquidate(tokenIds);
        assertTrue(liquidatedIDs.length == 0, "Liquidation should have failed");

        // By setting the price just below liquidation price, the position should be liquidatable.
        uint256 collateralPrice = (liqPrice - 1e10) / 1e10;
        setCollateralPrice(collateralPrice);
        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position should be liquidatable");

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );
        uint256 liquidationFee = liquidationModProxy.getLiquidationFee(tokenId);

        assertGt(
            alicePositionSummary.marginAfterSettlement,
            0,
            "Position must not be underwater (not negative margin)"
        );
        assertGt(
            uint256(alicePositionSummary.marginAfterSettlement),
            liquidationFee,
            "Remaining margin should be higher than liquidation fee"
        );

        vm.startPrank(liquidator);

        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();
        uint256 remainingMargin = uint256(alicePositionSummary.marginAfterSettlement) - liquidationFee;

        assertEq(
            liquidatorBalanceAfter - liquidatorBalanceBefore,
            liquidationFee,
            "Liquidator fee not awarded correctly"
        );

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }

        // Note: We are not taking into account the settled funding fees as this test won't produce any.
        assertApproxEqAbs(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            int256(remainingMargin) - alicePositionSummary.profitLoss,
            1,
            "Alice's margin should be given to the LPs"
        );

        // The position should not exist in the `_positions` mapping.
        assertTrue(vaultProxy.getPosition(tokenId).marginDeposited == 0, "Position should have been deleted");
        assertEq(
            controllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            0,
            "Total funding and PnL should have settled"
        );
    }

    function test_liquidate_when_token_locked() public {
        setCollateralPrice(1000e8);

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        announceCloseLeverage({traderAccount: alice, tokenId: tokenId, keeperFeeAmount: 0});

        setCollateralPrice(750e8);

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);
    }

    // The test here checks that global position data is updated correctly after a liquidation of a position heavily underwater.
    // By heavily underwater, we mean that the margin after settlement is more negative than the margin deposited for the position.
    // Now when such a position is liquidated, the funding fees settled for this position should be reversed.
    // Let's say the market was skewed long the entire time the position was open which means that the longs were paying the LPs funding fees.
    // As this bad position was not liquidated in time, it is still paying funding fees to the LPs.
    // But if the position doesn't have enough margin to pay funding fees, who is actually paying for it?
    // The answer is other traders. This is because the funding fees are settled globally and not per position.
    // So when a position is liquidated, the funding fees settled for that position should be reversed and added to the global margin deposited
    // and also the stable collateral total should be updated accordingly.
    // This is what the test checks.
    function test_liquidation_when_position_extremely_underwater() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 1e18,
            additionalSize: 24e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 90e18,
            additionalSize: 92e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.006e18);
        controllerModProxy.setMaxVelocitySkew(0.2e18);

        // Note that the amount of days to be skipped has been chosen arbitrarily.
        skip(15 days);

        setCollateralPrice(1000e8);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        controllerModProxy.settleFundingFees();

        uint256 liquidatorBalanceBefore = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalBefore = vaultProxy.stableCollateralTotal();

        LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();
        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );

        assertLt(alicePositionSummary.marginAfterSettlement, 0, "Position should be underwater");

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        uint256 liquidatorBalanceAfter = collateralAsset.balanceOf(liquidator);
        uint256 stableCollateralTotalAfter = vaultProxy.stableCollateralTotal();
        LeverageModuleStructs.PositionSummary memory bobPositionSummaryAfterLiquidation = leverageModProxy
            .getPositionSummary(tokenId2);

        assertApproxEqAbs(
            int256(vaultProxy.getGlobalPositions().marginDepositedTotal),
            int256(90e18) + bobPositionSummaryAfterLiquidation.accruedFunding,
            2, // account for rounding adjustments
            "Global margin deposited should be equal to the remaining margin of the other position"
        );

        assertEq(liquidatorBalanceAfter, liquidatorBalanceBefore, "Liquidator fee should not have been awarded");
        assertEq(
            int256(stableCollateralTotalAfter) - int256(stableCollateralTotalBefore),
            alicePositionSummary.marginAfterSettlement -
                alicePositionSummary.profitLoss -
                marketSummary.accruedFundingTotalByLongs,
            "Stable collateral total after liquidation incorrect"
        );

        assertEq(vaultProxy.getPosition(tokenId).marginDeposited, 0, "Position should have been deleted");

        {
            FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();

            // Total collateral in the vault is the sum of the stable collateral and the margin deposited.
            // Note that we are not adding or subtracting the funding fees given that settlement of the same
            // is accounted for already in the `stableCollateralTotal` or `marginDepositedTotal` variables
            // in the `settleFundingFees` function in the vault contract.
            assertEq(
                int256(stableCollateralTotalAfter) + vaultSummary.globalPositions.marginDepositedTotal,
                int256(collateralAsset.balanceOf(address(vaultProxy))),
                "Vault balance incorrect"
            );
        }
    }

    // This test checks that the an order announced by a user which isn't associated with his liquidatable position
    // isn't deleted after the position is liquidated.
    function test_unassociated_order_deletion_after_liquidation() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);
        uint256 newCollateralPrice = (liqPrice - 1e18) / 1e10;

        setCollateralPrice(newCollateralPrice);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Position should be liquidatable");

        // Alice wants to desposit 1 collateralAsset into the LP.
        announceStableDeposit({traderAccount: alice, depositAmount: 1e18, keeperFeeAmount: 0});

        // Liquidate the position before the announcement order gets executed.
        vm.startPrank(liquidator);

        bytes[] memory priceUpdateData = getPriceUpdateData(newCollateralPrice);
        liquidationModProxy.liquidate{value: 1}(tokenId, priceUpdateData);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);

        // The position should be liquidated.
        assertEq(position.marginDeposited, 0, "Position should have been liquidated");

        // The order should exist in the order announcement module.
        assertTrue(
            orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType != DelayedOrderStructs.OrderType.None,
            "Unassociated order should exist"
        );

        // Skip minimum time for the order to be executed and execute the order.
        skip(orderAnnouncementModProxy.minExecutabilityAge());

        executeStableDeposit({traderAccount: alice, keeperAccount: keeper, oraclePrice: newCollateralPrice});

        assertTrue(
            orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType == DelayedOrderStructs.OrderType.None,
            "Unassociated order should have been deleted"
        );
    }

    // This test checks that the a position adjustment order announced by a user which is associated with his liquidatable position
    // is deleted after the position is liquidated.
    function test_adjustment_order_deletion_after_liquidation() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);
        uint256 newCollateralPrice = (liqPrice - 1e18) / 1e10;

        setCollateralPrice(newCollateralPrice);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Position should be liquidatable");

        // Alice wants to adjust her position to not get liquidated
        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: tokenId,
            marginAdjustment: 50e18,
            additionalSizeAdjustment: 0,
            keeperFeeAmount: 0
        });

        uint256 aliceBalanceBeforeLiquidation = collateralAsset.balanceOf(alice);

        // Liquidate the position before the announcement order gets executed.
        vm.startPrank(liquidator);

        bytes[] memory priceUpdateData = getPriceUpdateData(newCollateralPrice);
        liquidationModProxy.liquidate{value: 1}(tokenId, priceUpdateData);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);

        // The position should be liquidated
        assertEq(position.marginDeposited, 0, "Position should have been liquidated");

        vm.startPrank(keeper);

        // The order shouldn't exist in the order announcement module.
        assertTrue(
            orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType == DelayedOrderStructs.OrderType.None,
            "Associated order should have been deleted"
        );
        assertEq(
            collateralAsset.balanceOf(alice) - aliceBalanceBeforeLiquidation,
            50e18 + mockKeeperFee.getKeeperFee(),
            "Alice should have received the margin adjustment funds"
        );
    }

    // This test checks that the a position close order announced by a user which is associated with his liquidatable position
    // is deleted after the position is liquidated.
    function test_close_order_deletion_after_liquidation() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Alice opens a position with 50 collateralAsset margin
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = viewer.liquidationPrice(tokenId);
        uint256 newCollateralPrice = (liqPrice - 1e18) / 1e10;

        setCollateralPrice(newCollateralPrice);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Position should be liquidatable");

        // Alice wants to adjust her position to not get liquidated
        announceCloseLeverage({traderAccount: alice, tokenId: tokenId, keeperFeeAmount: 0});

        uint256 aliceBalanceBeforeLiquidation = collateralAsset.balanceOf(alice);

        // Liquidate the position before the announcement order gets executed.
        vm.startPrank(liquidator);

        bytes[] memory priceUpdateData = getPriceUpdateData(newCollateralPrice);
        liquidationModProxy.liquidate{value: 1}(tokenId, priceUpdateData);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);

        // The position should be liquidated
        assertEq(position.marginDeposited, 0, "Position should have been liquidated");

        vm.startPrank(keeper);

        // The order shouldn't exist in the order announcement module.
        assertTrue(
            orderAnnouncementModProxy.getAnnouncedOrder(alice).orderType == DelayedOrderStructs.OrderType.None,
            "Associated order should have been deleted"
        );
        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBeforeLiquidation,
            "Alice should not have received any funds"
        );
    }
}
