// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";
import "src/interfaces/IChainlinkAggregatorV3.sol";

import "forge-std/console2.sol";
import "forge-std/StdMath.sol";

/// @dev Note that the assertions in all but 2 tests are not very strict because the funding rate is calculated
/// without assuming time delays between announcement and execution steps of an order. This is to keep the tests
/// readable. The 2 strict tests are:
/// 1) test_accrued_funding_accounting_when_funding_rate_flips_from_positive_to_negative_with_intermediate_settlements
/// 2) test_accrued_funding_accounting_when_funding_rate_flips_from_positive_to_negative_no_intermediate_settlements
contract MinFundingRateTest is Setup, OrderHelpers, ExpectRevert {
    using stdMath for *;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);
        controllerModProxy.setMinFundingRate(0); // minimum 0% funding rate

        disableChainlinkExpiry();

        // Disable the executability delays and expiry times for easier testing.
        // vaultProxy.setExecutabilityAge(1, 1);
    }

    // Test case which checks if the accounting for unrecordedFundingRate is correct when settlement is not done often
    // and the funding rate hits the lower bound.
    function test_pnl_no_price_change_short_skew_funding_cap_negative_with_no_intermediate_settlement() public {
        controllerModProxy.setMinFundingRate(-0.01e18); // minimum -1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e10,
            "Current funding rate should be approx -0.005e18 after 4 hours"
        );

        skip(4 hours); // should reach the min funding rate cap after 8 hours

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            1e6,
            "Current funding rate limit of -0.01e18 should be reached after 8 hours"
        );

        skip(16 hours); // total skip of 1 day

        assertEq(leverageModProxy.getPositionSummary(tokenId).profitLoss, 0, "PnL for position 1 should be 0");
        assertEq(controllerModProxy.currentFundingRate(), -0.01e18, "Current funding rate should be -0.01e18");

        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        assertEq(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            "Stable collateral per share should not change after settleFundingFees"
        );

        int256 expectedAccruedFunding1 = ((0.005e18 * 100e18 * 8) + // first 8 hours
            (0.01e18 * 100e18 * 8) + // second 8 hours
            (0.01e18 * 100e18 * 8)); // third 8 hours
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~0.833% after skipping 1 day"
        );

        skip(1 days - orderAnnouncementModProxy.minExecutabilityAge());

        // Equivalent to saying that the funding rate is -0.01e18 for 1 day (three 8 hour periods).
        int256 expectedAccruedFunding2 = (24 * 0.01e18 * 100e18) / 24e18;

        assertEq(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            "Current funding rate should still be -0.01e18 after skipping another day"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 3)) +
                    expectedAccruedFunding1 +
                    expectedAccruedFunding2
            ),
            1e6,
            "Alice's should receive a bit more than her original margin because of the negative min funding rate cap"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 4),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_pnl_no_price_change_short_skew_funding_cap_negative_with_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(-0.01e18); // minimum -1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e6,
            "Current funding rate should be approx -0.005e18 after 4 hours"
        );

        skip(4 hours); // should reach the min funding rate cap after 8 hours
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            1e6,
            "Current funding rate limit of -0.01e18 should be reached after 8 hours"
        );

        skip(16 hours); // total skip of 1 day
        controllerModProxy.settleFundingFees();

        assertEq(leverageModProxy.getPositionSummary(tokenId).profitLoss, 0, "PnL for position 1 should be 0");
        assertEq(controllerModProxy.currentFundingRate(), -0.01e18, "Current funding rate should be -0.01e18");
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        assertEq(
            stableCollateralPerShareBefore,
            stableModProxy.stableCollateralPerShare(),
            "Stable collateral per share should not change after settleFundingFees"
        );
        assertEq(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            "Current funding rate should still be -0.01e18 after settlement"
        );
        int256 expectedAccruedFunding = ((0.005e18 * 100e18 * 8) + // first 8 hours
            (0.01e18 * 100e18 * 8) + // second 8 hours
            (0.01e18 * 100e18 * 8)); // third 8 hours
        expectedAccruedFunding = expectedAccruedFunding / 24 / 1e18;
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for position 1 should be ~0.833% after skipping 1 day"
        );

        // Since any delay in order execution is not considered in the expected funding rate calculation,
        // we skip the time accordingly.
        skip(1 days - orderAnnouncementModProxy.minExecutabilityAge());
        controllerModProxy.settleFundingFees();

        // Equivalent to saying that the funding rate is -0.01e18 for 1 day (three 8 hour periods).
        int256 expectedAccruedFunding2 = (24 * 0.01e18 * 100e18) / 24e18;

        assertEq(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            "Current funding rate should still be -0.01e18 after skipping another day"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 3)) +
                    expectedAccruedFunding +
                    expectedAccruedFunding2
            ),
            1e6,
            "Alice's should receive a bit more than her original margin because of the negative min funding rate cap"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 4),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_accrued_funding_accounting_when_funding_rate_flips_from_negative_to_positive_no_intermediate_settlements()
        public
    {
        controllerModProxy.setMinFundingRate(-0.01e18); // minimum -1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e6,
            "Current funding rate should be approx -0.005e18 after 4 hours"
        );

        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

        // The following time skip will make the funding rate exactly 0.005e18.
        skip(8 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.005e18,
            1e6,
            "Current funding rate should be approx 0.005e18 after 8 hours after leverage open"
        );

        // We expect no change to accrued funding because the funding rate flipped from -0.005e18 to 0.005e18
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            accruedFundingBefore,
            0.1e6,
            "Accrued funding for position 1 should not change after funding reverses by the same margin"
        );

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.01e18, // 0.03 * 12 / 24 - 0.005 => maxVelocity * proportionalElapsedTime + lastRecomputedFundingRate
            1e6,
            "Current funding rate should be approx 0.01e18 after 16 hours"
        );

        int256 expectedAccruedFunding1 = ((0.005e18 / 2) * 100e18 * 4) +
            ((0.005e18 / 2) * 100e18 * 4) +
            ((-0.005e18 / 2) * 100e18 * 4) +
            ((-0.015e18 / 2) * 100e18 * 4);
        int256 expectedAccruedFunding2 = ((0.005e18 / 2) * 135e18 * 4) +
            ((-0.005e18 / 2) * 135e18 * 4) +
            ((-0.015e18 / 2) * 135e18 * 4);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24 / 1e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24 / 1e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~0.0833% after skipping 16 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 1 should be ~ -0.125% after skipping 16 hours"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice's should receive a bit more than her original margin because of the negative min funding rate in the beginning"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_accrued_funding_accounting_when_funding_rate_flips_from_negative_to_positive_with_intermediate_settlements()
        public
    {
        controllerModProxy.setMinFundingRate(-0.01e18); // minimum -1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());
        controllerModProxy.settleFundingFees();

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e6,
            "Current funding rate should be approx -0.005e18 after 4 hours"
        );

        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

        // The following time skip will make the funding rate exactly 0.005e18.
        skip(8 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.005e18,
            1e6,
            "Current funding rate should be approx 0.005e18 after 8 hours after leverage open"
        );

        // We expect the accrued funding to be 0 after between 4hrs and 12 hrs because the funding rate flipped from negative to positive.
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            accruedFundingBefore,
            1e6,
            "Accrued funding for position 1 should be ~0.041667% after skipping 12 hours"
        );

        skip(4 hours);
        controllerModProxy.settleFundingFees();

        int256 expectedAccruedFunding1 = ((0.005e18 / 2) * 100e18 * 4) +
            ((0.005e18 / 2) * 100e18 * 4) +
            ((-0.005e18 / 2) * 100e18 * 4) +
            ((-0.015e18 / 2) * 100e18 * 4);
        int256 expectedAccruedFunding2 = ((0.005e18 / 2) * 135e18 * 4) +
            ((-0.005e18 / 2) * 135e18 * 4) +
            ((-0.015e18 / 2) * 135e18 * 4);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24 / 1e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24 / 1e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~0.0833% after skipping 16 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 2 should be ~ -0.125% after skipping 16 hours"
        );

        // `vm.warp` sets the timestamp to the desired value without affecting any other state.
        // Here, we have used it to get the accrued funding value at the time of order execution.
        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        // We expect no change to accrued funding because the funding rate flipped from -0.005e18 to 0.005e18
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            1e6,
            "Current funding rate should be approx 0.01e18 after 8 hours after leverage adjust"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice's should receive a bit more than her original margin because of the negative min funding rate in the beginning"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_accrued_funding_accounting_when_funding_rate_flips_from_positive_to_negative_no_intermediate_settlements()
        public
    {
        controllerModProxy.setMinFundingRate(-0.03e18); // minimum -3%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        int256 accruedFundingBeforeAlice;

        {
            int256[] memory fundingMarks = new int256[](10);
            uint256[] memory timeMarks = new uint256[](10);

            timeMarks[0] = block.timestamp;
            skip(4 hours);

            assertApproxEqAbs(
                controllerModProxy.currentFundingRate(),
                0.005e18,
                1e6,
                "Current funding rate should be approx 0.005e18 after 4 hours"
            );

            announceAndExecuteDeposit({
                traderAccount: alice,
                keeperAccount: keeper,
                depositAmount: stableDeposit,
                oraclePrice: collateralPrice,
                keeperFeeAmount: 0
            });

            fundingMarks[0] = controllerModProxy.currentFundingRate();
            timeMarks[1] = block.timestamp;

            // Time at which the funding rate becomes 0.
            timeMarks[2] = timeMarks[1] + (stdMath.abs(fundingMarks[0]) * 24 * 60 * 60) / 0.03e18 + 1;

            // Calculating time required to flip the funding rate from -0.005 to +0.005.
            uint256 timeUntilFlip = uint256((2 * fundingMarks[0] * 24 * 60 * 60) / 0.03e18);

            skip(timeUntilFlip + 1); // +1 for rounding error.

            fundingMarks[1] = controllerModProxy.currentFundingRate();
            timeMarks[3] = block.timestamp;

            assertApproxEqAbs(
                fundingMarks[0],
                -fundingMarks[1],
                1e6,
                "Current funding rate should be flipped from -0.005e18 to 0.005e18"
            );

            // -ve sign for funding marks since funding rate is the rate at which traders pay the LPs.
            // The following calculation is for the area under the following curves:
            // 1) From when the funding rate becomes 0 => 0.005 which takes 4 hours.
            // 2) From when the funding rate becomes 0.005 => 0 which takes 4 hours.
            // 3) From when the funding rate becomes 0 => -0.005 which takes 4 hours.
            // Note that the area under the curves 1 and 2 are same and hence the denominator of the first term is 1e36.
            int256 expectedAccruedFunding = ((-fundingMarks[0] *
                120e18 *
                int256(_getProportionalElapsedTime(timeMarks[1], timeMarks[0]))) / 1e36) +
                ((-fundingMarks[1] * 120e18 * int256(_getProportionalElapsedTime(timeMarks[3], timeMarks[2]))) / 2e36);
            accruedFundingBeforeAlice = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

            assertApproxEqAbs(
                accruedFundingBeforeAlice,
                expectedAccruedFunding,
                1e6,
                "Accrued funding for position 1 should be ~ -0.041667% after skipping 12 hours"
            );

            // Skipping time to make the funding rate exactly -0.01e18.
            skip((stdMath.abs(-0.01e18 - fundingMarks[1]) * 24 * 60 * 60) / 0.03e18 + 1); // +1 for rounding error.

            fundingMarks[2] = controllerModProxy.currentFundingRate();
            timeMarks[4] = block.timestamp;

            assertApproxEqAbs(
                fundingMarks[2],
                -0.01e18,
                1e6,
                "Current funding rate should be approx -0.01e18 after 8 hours after leverage adjust"
            );

            // We are setting the timestamp such that the expected accrued funding calculations
            // take into account the order execution delay.
            vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());

            fundingMarks[2] = controllerModProxy.currentFundingRate();
            timeMarks[4] = block.timestamp;

            // The following calculation is for the area under the following curves:
            // 1) From when the funding rate becomes -0.005 => -0.01 which takes 4 hours.
            //    The shape it forms (when drawn on funding rate vs time graph) is a right-angle
            //    trapezoid. The area of such a shape is (a + b) * h / 2.
            // Note that this area is added to the previously calculated sum.
            expectedAccruedFunding +=
                (-(fundingMarks[2] + fundingMarks[1]) *
                    120e18 *
                    int256(_getProportionalElapsedTime(timeMarks[4], timeMarks[3]))) /
                2e36;

            accruedFundingBeforeAlice = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

            assertApproxEqAbs(
                accruedFundingBeforeAlice,
                expectedAccruedFunding,
                1e6,
                "Accrued funding for position 1 should be ~0.0833% after skipping 16 hours"
            );

            // Reset the time to original time.
            vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());
        }

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - 2 * stableDeposit - (mockKeeperFee.getKeeperFee() * 4)) +
                    accruedFundingBeforeAlice
            ),
            1e6,
            "Alice didn't receive correct amount back after closing the position"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 5),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_accrued_funding_accounting_when_funding_rate_flips_from_positive_to_negative_with_intermediate_settlements()
        public
    {
        controllerModProxy.setMinFundingRate(-0.03e18); // minimum -3%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        int256 accruedFundingBeforeAlice;

        {
            int256[] memory fundingMarks = new int256[](10);
            uint256[] memory timeMarks = new uint256[](10);

            timeMarks[0] = block.timestamp;
            skip(4 hours);
            controllerModProxy.settleFundingFees();

            assertApproxEqAbs(
                controllerModProxy.currentFundingRate(),
                0.005e18,
                1e6,
                "Current funding rate should be approx 0.005e18 after 4 hours"
            );

            announceAndExecuteDeposit({
                traderAccount: alice,
                keeperAccount: keeper,
                depositAmount: stableDeposit,
                oraclePrice: collateralPrice,
                keeperFeeAmount: 0
            });

            fundingMarks[0] = controllerModProxy.currentFundingRate();
            timeMarks[1] = block.timestamp;

            // Time at which the funding rate becomes 0.
            timeMarks[2] = timeMarks[1] + (stdMath.abs(fundingMarks[0]) * 24 * 60 * 60) / 0.03e18 + 1;

            // Calculating time required to flip the funding rate from -0.005 to +0.005.
            uint256 timeUntilFlip = uint256((2 * fundingMarks[0] * 24 * 60 * 60) / 0.03e18);

            skip(timeUntilFlip + 1); // +1 for rounding error.

            fundingMarks[1] = controllerModProxy.currentFundingRate();
            timeMarks[3] = block.timestamp;
            controllerModProxy.settleFundingFees();

            assertApproxEqAbs(
                fundingMarks[0],
                -fundingMarks[1],
                1e6,
                "Current funding rate should be flipped from -0.005e18 to 0.005e18"
            );

            // -ve sign for funding marks since funding rate is the rate at which traders pay the LPs.
            // The following calculation is for the area under the following curves:
            // 1) From when the funding rate becomes 0 => 0.005 which takes 4 hours.
            // 2) From when the funding rate becomes 0.005 => 0 which takes 4 hours.
            // 3) From when the funding rate becomes 0 => -0.005 which takes 4 hours.
            // Note that the area under the curves 1 and 2 are same and hence the denominator of the first term is 1e36.
            int256 expectedAccruedFunding = ((-fundingMarks[0] *
                120e18 *
                int256(_getProportionalElapsedTime(timeMarks[1], timeMarks[0]))) / 1e36) +
                ((-fundingMarks[1] * 120e18 * int256(_getProportionalElapsedTime(timeMarks[3], timeMarks[2]))) / 2e36);
            accruedFundingBeforeAlice = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

            assertApproxEqAbs(
                accruedFundingBeforeAlice,
                expectedAccruedFunding,
                1e6,
                "Accrued funding for position 1 should be ~ -0.041667% after skipping 12 hours"
            );

            // Skipping time to make the funding rate exactly -0.01e18.
            skip((stdMath.abs(-0.01e18 - fundingMarks[1]) * 24 * 60 * 60) / 0.03e18 + 1); // +1 for rounding error.

            fundingMarks[2] = controllerModProxy.currentFundingRate();
            timeMarks[4] = block.timestamp;
            controllerModProxy.settleFundingFees();

            assertApproxEqAbs(
                fundingMarks[2],
                -0.01e18,
                1e6,
                "Current funding rate should be approx -0.01e18 after 8 hours after leverage adjust"
            );

            // We are setting the timestamp such that the expected accrued funding calculations
            // take into account the order execution delay.
            vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());

            fundingMarks[2] = controllerModProxy.currentFundingRate();
            timeMarks[4] = block.timestamp;

            // The following calculation is for the area under the following curves:
            // 1) From when the funding rate becomes -0.005 => -0.01 which takes 4 hours.
            //    The shape it forms (when drawn on funding rate vs time graph) is a right-angle
            //    trapezoid. The area of such a shape is (a + b) * h / 2.
            // Note that this area is added to the previously calculated sum.
            expectedAccruedFunding +=
                (-(fundingMarks[2] + fundingMarks[1]) *
                    120e18 *
                    int256(_getProportionalElapsedTime(timeMarks[4], timeMarks[3]))) /
                2e36;

            accruedFundingBeforeAlice = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

            assertApproxEqAbs(
                accruedFundingBeforeAlice,
                expectedAccruedFunding,
                1e6,
                "Accrued funding for position 1 should be ~0.0833% after skipping 16 hours"
            );

            // Reset the time to original time.
            vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());
        }

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - 2 * stableDeposit - (mockKeeperFee.getKeeperFee() * 4)) +
                    accruedFundingBeforeAlice
            ),
            1e6,
            "Alice didn't receive correct amount back after closing the position"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 5),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_zero_starting_with_LP_skewed_market_no_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0); // minimum 0%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 4 hours"
        );

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // The following time skip will make the funding rate exactly 0.01e18.
        skip(8 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            1e6,
            "Current funding rate should be approx 0.01e18 after 8 hours after new leverage position creation"
        );

        int256 expectedAccruedFunding1 = ((-0.01e18 / 2) * 100e18 * 8);
        int256 expectedAccruedFunding2 = ((-0.01e18 / 2) * 135e18 * 8);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~ -0.166% after skipping 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 2 should be ~ -0.166% after skipping 1 day"
        );

        // `vm.warp` sets the timestamp to the desired value without affecting any other state.
        // Here, we have used it to get the accrued funding value at the time of order execution.
        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // `vm.warp` sets the timestamp to the desired value without affecting any other state.
        // Here, we have used it to get the accrued funding value at the time of order execution.
        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_zero_starting_with_LP_skewed_market_with_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0); // minimum 0%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 4 hours"
        );

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // The following time skip will make the funding rate exactly 0.01e18.
        skip(8 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            1e6,
            "Current funding rate should be approx 0.01e18 after 8 hours after new leverage position creation"
        );

        int256 expectedAccruedFunding1 = ((-0.01e18 / 2) * 100e18 * 8);
        int256 expectedAccruedFunding2 = ((-0.01e18 / 2) * 135e18 * 8);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~ -0.1666% after skipping 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 2 should be ~ -0.1666% after skipping 1 day"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_zero_starting_with_long_skewed_market_no_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0); // minimum 0%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.005e18,
            1e6,
            "Current funding rate should be approx 0.005e18 after 4 hours"
        );

        // The following time skip will make the funding rate exactly 0.
        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 8 hours"
        );

        int256 expectedAccruedFunding = ((-0.005e18 / 2) * 120e18 * 4) + ((-0.005e18 / 2) * 120e18 * 4);
        expectedAccruedFunding = expectedAccruedFunding / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for the position should be ~ -0.0833% after skipping 12 hours"
        );

        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            accruedFundingBefore,
            1e6,
            "Accrued funding for the position should be the same as before during the time period between 8hrs and 12hrs"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - 2 * stableDeposit - (mockKeeperFee.getKeeperFee() * 4)) +
                    accruedFundingBefore
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 5),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_zero_starting_with_long_skewed_market_with_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0); // minimum 0%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());
        controllerModProxy.settleFundingFees();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.005e18,
            1e6,
            "Current funding rate should be approx 0.005e18 after 4 hours"
        );

        // The following time skip will make the funding rate exactly 0.
        skip(4 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 8 hours"
        );

        int256 expectedAccruedFunding = ((-0.005e18 / 2) * 120e18 * 4) + ((-0.005e18 / 2) * 120e18 * 4);
        expectedAccruedFunding = expectedAccruedFunding / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for the position should be ~ -0.0833% after skipping 12 hours"
        );

        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));

        skip(4 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            accruedFundingBefore,
            1e6,
            "Accrued funding for the position should be the same as before during the time period between 8hrs and 12hrs"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - 2 * stableDeposit - (mockKeeperFee.getKeeperFee() * 4)) +
                    accruedFundingBefore
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 5),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_positive_starting_with_LP_skewed_market_no_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0.01e18); // minimum 1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            "Current funding rate should be 0.01e18 right after market creation"
        );

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());

        assertEq(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            "Current funding rate should be 0.01e18 after 4 hours"
        );

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(8 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.02e18,
            1e6,
            "Current funding rate should be approx 0.02e18 after 8 hours after new leverage position creation"
        );

        int256 expectedAccruedFunding1 = (-0.01e18 * 100e18 * 4) + ((-0.03e18 / 2) * 100e18 * 8);
        int256 expectedAccruedFunding2 = ((-0.03e18 / 2) * 135e18 * 8);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~ -0.666% after skipping 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 2 should be ~ -0.5% after skipping 1 day"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_positive_starting_with_LP_skewed_market_with_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0.01e18); // minimum 1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            "Current funding rate should be 0.01e18 right after market creation"
        );

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());
        controllerModProxy.settleFundingFees();

        assertEq(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            "Current funding rate should be 0.01e18 after 4 hours"
        );

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 135e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(8 hours);
        controllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.02e18,
            1e6,
            "Current funding rate should be approx 0.02e18 after 8 hours after new leverage position creation"
        );

        int256 expectedAccruedFunding1 = (-0.01e18 * 100e18 * 4) + ((-0.03e18 / 2) * 100e18 * 8);
        int256 expectedAccruedFunding2 = ((-0.03e18 / 2) * 135e18 * 8);
        expectedAccruedFunding1 = expectedAccruedFunding1 / 24e18;
        expectedAccruedFunding2 = expectedAccruedFunding2 / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding1,
            1e6,
            "Accrued funding for position 1 should be ~ -0.666% after skipping 12 hours"
        );
        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2)),
            expectedAccruedFunding2,
            1e6,
            "Accrued funding for position 2 should be ~ -0.5% after skipping 1 day"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore1 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore2 = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId2));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 5)) +
                    accruedFundingBefore1 +
                    accruedFundingBefore2
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_min_funding_rate_positive_starting_with_long_skewed_market_no_intermediate_settlements() public {
        controllerModProxy.setMinFundingRate(0.01e18); // minimum 1%/day funding rate

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.015e18,
            1e6,
            "Current funding rate should be approx 0.015e18 after 4 hours"
        );

        // The following time skip will make the funding rate exactly 0.01e18.
        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            1e6,
            "Current funding rate should be approx 0.01e18 after 8 hours"
        );

        skip(4 hours);

        int256 expectedAccruedFunding = ((-0.025e18 / 2) * 120e18 * 4) +
            ((-0.025e18 / 2) * 120e18 * 4) +
            (-0.01e18 * 120e18 * 4);
        expectedAccruedFunding = expectedAccruedFunding / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for the position should be ~ -0.5833% after skipping 12 hours"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - 2 * stableDeposit - (mockKeeperFee.getKeeperFee() * 4)) +
                    accruedFundingBefore
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 5),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_funding_rate_after_resetting_min_funding_rate_to_higher_rate_than_current_funding_rate() public {
        controllerModProxy.setMinFundingRate(-0.01e18);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e6,
            "Current funding rate should be approx -0.005e18 after 4 hours"
        );

        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        vm.startPrank(admin);
        controllerModProxy.setMinFundingRate(0.01e18);

        assertEq(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            accruedFundingBefore,
            "Accrued funding for the position should be the same as before after setting min funding rate to 0.01e18"
        );
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            stableCollateralPerShareBefore,
            "Stable collateral per share should be the same as before after setting min funding rate to 0.01e18"
        );

        skip(4 hours);

        assertEq(
            controllerModProxy.currentFundingRate(),
            0.01e18,
            "Current funding rate should be 0.01e18 after setting min funding rate to 0.01e18"
        );

        int256 expectedAccruedFunding = (-0.01e18 * 100e18 * 4) + ((0.005e18 / 2) * 100e18 * 4);
        expectedAccruedFunding = expectedAccruedFunding / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for the position should be ~ -0.125% after skipping 8 hours"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 3)) + accruedFundingBefore
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 4),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function test_funding_rate_after_resetting_min_funding_rate_to_lower_rate_than_current_funding_rate() public {
        controllerModProxy.setMinFundingRate(0);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            0,
            1e6,
            "Current funding rate should be approx 0 after 4 hours"
        );

        vm.startPrank(admin);
        controllerModProxy.setMinFundingRate(-0.01e18);

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.005e18,
            1e6,
            "Current funding rate should be approx 0.005e18 after setting min funding rate to 0.01e18"
        );

        skip(4 hours);

        assertApproxEqAbs(
            controllerModProxy.currentFundingRate(),
            -0.01e18,
            1e6,
            "Current funding rate should be approx 0.01e18 after skipping 8 hours"
        );

        skip(4 hours);

        int256 expectedAccruedFunding = ((0.005e18 / 2) * 100e18 * 4) +
            ((0.015e18 / 2) * 100e18 * 4) +
            (0.01e18 * 100e18 * 4);
        expectedAccruedFunding = expectedAccruedFunding / 24e18;

        assertApproxEqAbs(
            controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId)),
            expectedAccruedFunding,
            1e6,
            "Accrued funding for the position should be ~ 0.33% after skipping 16 hours"
        );

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 accruedFundingBefore = controllerModProxy.accruedFunding(vaultProxy.getPosition(tokenId));
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            uint256(
                int256(aliceBalanceBefore - stableDeposit - (mockKeeperFee.getKeeperFee() * 3)) + accruedFundingBefore
            ),
            1e6,
            "Alice should receive correct amount after closing all positions"
        );

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            200_000,
            "Vault should have no funds left"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 4),
            1e6,
            "Alice's should receive all her funds back"
        );
    }

    function _getProportionalElapsedTime(uint256 timeAfter, uint256 timeBefore) private pure returns (uint256) {
        return ((timeAfter - timeBefore) * 1e18) / 1 days;
    }
}
