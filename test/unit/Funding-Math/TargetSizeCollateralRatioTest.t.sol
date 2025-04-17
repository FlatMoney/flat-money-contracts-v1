// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "src/interfaces/IChainlinkAggregatorV3.sol";
import "../../helpers/OrderHelpers.sol";

abstract contract TargetSizeCollateralRatioTestBase is OrderHelpers {
    uint256 internal TARGET_SIZE_COLLATERAL_RATIO;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(admin);

        controllerModProxy.setTargetSizeCollateralRatio(TARGET_SIZE_COLLATERAL_RATIO);
        controllerModProxy.setMaxFundingVelocity(0.03e18);
    }

    // This test checks that the funding rate should be zero in case we mint LP tokens and open a position at the same time
    // in the targetted skew ratio configuration.
    function test_funding_rate_should_be_zero_in_case_initial_market_condition_achieves_target_ratio() public {
        setCollateralPrice(1000e8);

        uint256 depositAmount = 100e18;
        uint256 size = (TARGET_SIZE_COLLATERAL_RATIO * depositAmount) / 1e18;

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: 50e18,
            additionalSize: size,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(1 days);

        assertEq(controllerModProxy.currentFundingRate(), 0, "Funding rate should be zero");
    }

    function test_funding_rate_negative_in_LP_skewed_market_after_accounting_for_target_ratio() public {
        setCollateralPrice(1000e8);

        uint256 depositAmount = 100e18;
        uint256 size = ((TARGET_SIZE_COLLATERAL_RATIO * depositAmount) / 1e18) - 1e18;

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: 50e18,
            additionalSize: size,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 stableCollateralTotalAfterSettlementBefore = stableModProxy.stableCollateralTotalAfterSettlement();

        skip(1 days);

        int256 expectedCurrentFundingRate;
        {
            int256 expectedProportionalSkew = ((int256(size) * 1e18) / int256(depositAmount)) -
                int256(TARGET_SIZE_COLLATERAL_RATIO);
            int256 expectedCurrentFundingVelocity = (expectedProportionalSkew *
                int256(controllerModProxy.maxFundingVelocity())) / int256(controllerModProxy.maxVelocitySkew());
            expectedCurrentFundingRate = expectedCurrentFundingVelocity;
        }

        int256 currentFundingRate = controllerModProxy.currentFundingRate();

        assertLt(currentFundingRate, 0, "Funding rate should be lesser than zero");
        assertEq(expectedCurrentFundingRate, currentFundingRate, "Incorrect funding rate");
        assertGt(
            stableCollateralTotalAfterSettlementBefore,
            stableModProxy.stableCollateralTotalAfterSettlement(),
            "Stable collateral total should decrease"
        );
    }

    function test_funding_rate_positive_in_long_skewed_market_after_accounting_for_target_ratio() public {
        setCollateralPrice(1000e8);

        uint256 depositAmount = 100e18;
        uint256 size = ((TARGET_SIZE_COLLATERAL_RATIO * depositAmount) / 1e18) + 1e18;

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: 50e18,
            additionalSize: size,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 stableCollateralTotalAfterSettlementBefore = stableModProxy.stableCollateralTotalAfterSettlement();

        skip(1 days);

        int256 expectedCurrentFundingRate;
        {
            int256 expectedProportionalSkew = ((int256(size) * 1e18) / int256(depositAmount)) -
                int256(TARGET_SIZE_COLLATERAL_RATIO);
            int256 expectedCurrentFundingVelocity = (expectedProportionalSkew *
                int256(controllerModProxy.maxFundingVelocity())) / int256(controllerModProxy.maxVelocitySkew());
            expectedCurrentFundingRate = expectedCurrentFundingVelocity;
        }

        int256 currentFundingRate = controllerModProxy.currentFundingRate();

        assertGt(currentFundingRate, 0, "Funding rate should be greater than zero");
        assertEq(expectedCurrentFundingRate, currentFundingRate, "Incorrect funding rate");
        assertLt(
            stableCollateralTotalAfterSettlementBefore,
            stableModProxy.stableCollateralTotalAfterSettlement(),
            "Stable collateral total should increase"
        );
    }

    // This test checks that the funding rate velocity should be max when the market has hit max velocity skew.
    // In this case, the market is long skewed.
    function test_funding_rate_when_hitting_max_velocity_skew_long_skewed_market() public {
        uint256 oraclePrice = 1000e8;
        setCollateralPrice(oraclePrice);

        uint256 depositAmount = 100e18;
        (uint256 size, ) = _getMaxSkewSize(depositAmount);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: 50e18,
            additionalSize: size,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        skip(1 days);

        uint256 collateralPerShareBeforeMint = 1e36 / (oraclePrice * 1e10);

        // Stable collateral per share when no shares have been minted is calculated as 1e36 / oraclePrice (in 18 decimals).
        uint256 expectedStableCollateralPerShare = collateralPerShareBeforeMint +
            (((collateralPerShareBeforeMint * ((controllerModProxy.maxFundingVelocity() / 2) * size)) / 1e18) /
                depositAmount);
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            expectedStableCollateralPerShare,
            "Incorrect stable collateral per share"
        );
        assertEq(
            controllerModProxy.currentFundingRate(),
            int256(controllerModProxy.maxFundingVelocity()),
            "Funding rate should be max"
        );
    }

    // This test checks that the funding rate velocity should be max when the market has hit max velocity skew.
    // In this case, the market is long skewed.
    function test_funding_rate_when_hitting_max_velocity_skew_LP_skewed_market() public {
        uint256 oraclePrice = 1000e8;
        setCollateralPrice(oraclePrice);

        uint256 depositAmount = 100e18;
        (, uint256 size) = _getMaxSkewSize(depositAmount);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            margin: 50e18,
            additionalSize: size,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        skip(1 days);

        uint256 collateralPerShareBeforeMint = 1e36 / (oraclePrice * 1e10);

        // Stable collateral per share when no shares have been minted is calculated as 1e36 / oraclePrice (in 18 decimals).
        uint256 expectedStableCollateralPerShare = collateralPerShareBeforeMint -
            (((collateralPerShareBeforeMint * ((controllerModProxy.maxFundingVelocity() / 2) * size)) / 1e18) /
                depositAmount);
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            expectedStableCollateralPerShare,
            "Incorrect stable collateral per share"
        );
        assertEq(
            controllerModProxy.currentFundingRate(),
            -int256(controllerModProxy.maxFundingVelocity()),
            "Funding rate should be max"
        );
    }

    // To understand how we calculated the size, see the following derivation:
    // maxVelocitySkew = 0.1e18 => When market is long/short skewed 10%, we want the funding rate velocity to be maximum value possible (maxFundingVelocity).
    // However, given there is a target skew ratio which basically means we are adding/subtracting an offset to the proportional skew, we need to account for that.
    // If the target skew is anything but 1, the max velocity skew will be affected i.e., the funding rate velocity will be maximum above or below the
    // configured maxVelocitySkew. Let's take an example:
    //      If the target skew ratio is 50/50 => 1, then the funding rate will change direction when:
    //          long_pos_size != short_pos_size.
    //      When ratio is 1 and maxVelocitySkew is 0.1, the funding rate will be max when:
    //          long_pos_size = short_pos_size * 1.1 or long_pos_size = short_pos_size * 0.9 (10% higher or lower).
    //      However, let's say the target skew ratio is 0.9, then the funding rate will change direction when:
    //          long_pos_size != short_pos_size * 0.9
    //      When ratio is 0.9 and maxVelocitySkew is 0.1, the funding rate will be max when:
    //          long_pos_size = short_pos_size or long_pos_size = short_pos_size * 0.8
    // The way to calculate the relation between longs and shorts is to solve for x in the following equation:
    //      long_pos_size = short_pos_size + x --- (1)
    //      +-maxVelocitySkew = ((total_shorts + x) / (total_shorts)) - TARGET_SIZE_COLLATERAL_RATIO --- (2)
    // So, the size is calculated as follows (ignoring 18 decimals for simplicity):
    //      sizeLongSkewedMarket => depositAmount * (TARGET_SIZE_COLLATERAL_RATIO + maxVelocitySkew)
    //      sizeShortSkewedMarket => depositAmount * (TARGET_SIZE_COLLATERAL_RATIO - maxVelocitySkew)
    function _getMaxSkewSize(
        uint256 depositAmount
    ) private view returns (uint256 longSkewedMarket, uint256 shortSkewedMarket) {
        uint256 maxVelocitySkew = controllerModProxy.maxVelocitySkew();

        return (
            (depositAmount * (TARGET_SIZE_COLLATERAL_RATIO + maxVelocitySkew)) / 1e18,
            (depositAmount * (TARGET_SIZE_COLLATERAL_RATIO - maxVelocitySkew)) / 1e18
        );
    }
}

contract TargetSizeCollateralRatioGreaterThanOneTest is TargetSizeCollateralRatioTestBase {
    function setUp() public override {
        // Targetting a market which is 10% long skewed.
        TARGET_SIZE_COLLATERAL_RATIO = 1.1e18;

        super.setUp();
    }
}

contract TargetSizeCollateralRatioLesserThanOneTest is TargetSizeCollateralRatioTestBase {
    function setUp() public override {
        // Targetting a market which is 10% short skewed.
        TARGET_SIZE_COLLATERAL_RATIO = 0.9e18;

        super.setUp();
    }
}

contract TargetSizeCollateralRatioEqualOneTest is TargetSizeCollateralRatioTestBase {
    function setUp() public override {
        // Targetting a delta neutral market (50/50).
        TARGET_SIZE_COLLATERAL_RATIO = 1e18;

        super.setUp();
    }
}
