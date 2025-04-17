// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "forge-std/console2.sol";

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";

contract ApproxLiquidationPriceTest is OrderHelpers {
    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);

        disableChainlinkExpiry();
    }

    function test_liquidation_price_stays_same_when_no_market_skew() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(2 days);

        // The difference between liquidation prices before and after skipping time shouldn't be off by more than +-$1.
        assertApproxEqAbs(
            viewer.liquidationPrice(0),
            liqPriceBefore,
            1e18,
            "Liquidation price changed significantly after some days"
        );
    }

    function test_liquidation_price_stays_same_when_no_market_skew_but_asset_price_increases() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(2 days);

        setCollateralPrice(2000e8);

        // The difference between liquidation prices before and after skipping time shouldn't be off by more than +-$1.
        assertApproxEqAbs(
            viewer.liquidationPrice(0),
            liqPriceBefore,
            1e18,
            "Liquidation price changed significantly after some days"
        );
    }

    function test_liquidation_price_stays_same_when_no_market_skew_but_asset_price_decreases() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(2 days);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setCollateralPrice((liqPriceBefore - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        // The difference between liquidation prices before and after skipping time shouldn't be off by more than +-$1.
        assertApproxEqAbs(
            viewer.liquidationPrice(0),
            liqPriceBefore,
            1e18,
            "Liquidation price changed significantly after some days"
        );
    }

    function test_liquidation_price_decreases_when_market_stable_skewed() public {
        setCollateralPrice(1000e8);

        // Alice deposits 100 collateralAsset and opens a position with 50 collateralAsset margin and 2x leverage.
        // Makes the market stable skewed.
        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(2 days);

        assertLt(viewer.liquidationPrice(0), liqPriceBefore, "Liquidation price should decrease after some days");
    }

    function test_liquidation_price_increases_when_market_long_skewed() public {
        setCollateralPrice(1000e8);

        // Alice deposits 100 collateralAsset and opens a position with 60 collateralAsset margin and 3x leverage.
        // Makes the market long skewed.
        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 60e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPriceBefore = viewer.liquidationPrice(0);

        skip(2 days);

        assertGt(viewer.liquidationPrice(0), liqPriceBefore, "Liquidation price should increase after some days");
    }
}
