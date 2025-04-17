// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import "../../../helpers/Setup.sol";
import "../../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract GetFlatcoinPriceInUSDTest is OrderHelpers {
    function setUp() public override {
        super.setUp();

        disableChainlinkExpiry();
    }

    function test_viewer_flatcoin_price_in_usd_when_no_deposit() public {
        setCollateralPrice(1e8);

        uint256 priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(priceInUsd, 1e18, "Incorrect price in USD when no deposits");

        setCollateralPrice(4242e8);

        priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(priceInUsd, (uint256(1e36) / 4242e18) * 4242, "Incorrect price in USD when no deposits");

        setCollateralPrice(1_000_000_000e8);

        priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(
            priceInUsd,
            1_000_000_000 * (uint256(1e36) / 1_000_000_000e18),
            "Incorrect price in USD when no deposits"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_single_deposit() public {
        vm.startPrank(alice);

        setCollateralPrice(1000e8);

        uint256 depositAmount = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 collateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(priceInUsd, 1e18, "Incorrect price in USD when single deposit");

        setCollateralPrice(4242e8);

        priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(priceInUsd, collateralPerShareBefore * uint256(4242), "Incorrect price in USD when single deposit");

        setCollateralPrice(1_000_000_000e8);

        priceInUsd = viewer.getFlatcoinPriceInUSD();
        assertEq(
            priceInUsd,
            collateralPerShareBefore * uint256(1_000_000_000),
            "Incorrect price in USD when single deposit"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_no_market_skew() public {
        setCollateralPrice(1000e8);

        // Disable trading fees so that they don't impact the results
        vm.startPrank(admin);
        vaultProxy.setStableWithdrawFee(0);
        vaultProxy.setLeverageTradingFee(0);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        // Enabling funding rate now that skew is anyway 0.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        skip(2 days);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();
        assertEq(priceInUsdAfter, priceInUsdBefore, "Incorrect price in USD when no market skew");
    }

    function test_viewer_flatcoin_price_in_usd_when_long_skewed_and_no_change_in_price() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2.2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // The price has to be greater than before because of the funding fees
        // paid to the LPs by longs.
        assertGt(
            priceInUsdAfter,
            priceInUsdBefore,
            "Price in USD should have increased when long skewed and no change in collateral price"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_stable_skewed_and_no_change_in_price() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // The price has to be lesser than before because of the funding fees
        // paid to the longs by LPs.
        assertLt(
            priceInUsdAfter,
            priceInUsdBefore,
            "Price in USD should have decreased when stable skewed and no change in collateral price"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_long_skewed_and_price_increases() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2.2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        // collateralAsset price has doubled.
        setCollateralPrice(2000e8);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // The price has to be lesser than before because of the profits gained by longs.
        // The funding fees paid by longs are offset by the profits gained by longs.
        assertLt(
            priceInUsdAfter,
            priceInUsdBefore,
            "Price in USD should have decreased when long skewed and collateral price increases"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_long_skewed_and_price_decreases() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2.2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        // collateralAsset price has reduced by 20%.
        setCollateralPrice(800e8);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // The price has to be greater than before because of the losses incurred by longs.
        // and funding fees paid by longs.
        assertGt(
            priceInUsdAfter,
            priceInUsdBefore,
            "Price in USD should have increased when long skewed and collateral price decreases"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_stable_skewed_and_price_increases() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        setCollateralPrice(2000e8);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // Since the market is stable skewed, the price of the collateralAsset impacts the price
        // of the flatcoin. The price of the flatcoin should increase because of the direct correlation
        // with the price of collateralAsset. However, It won't be equal to the price of collateralAsset because of the profits
        // gained by the longs and the funding fees paid by the LPs.
        assertTrue(
            priceInUsdAfter > priceInUsdBefore && priceInUsdAfter < 2000e18,
            "Price in USD should have increased but not equal to collateralAsset price"
        );
    }

    function test_viewer_flatcoin_price_in_usd_when_stable_skewed_and_price_decreases() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // 2x leverage position
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Enabling funding rate.
        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        uint256 priceInUsdBefore = viewer.getFlatcoinPriceInUSD();

        skip(2 days);

        // Price has been reduced by 50%.
        setCollateralPrice(500e8);

        uint256 priceInUsdAfter = viewer.getFlatcoinPriceInUSD();

        // Since 50% of LP token is not hedged, the price of the flatcoin should decrease by 50% of the unbacked amount (so 25%).
        // Also since the LPs are paying the longs, the price of the flatcoin should decrease even more than that.
        assertTrue(
            priceInUsdAfter < priceInUsdBefore && priceInUsdAfter < 0.75e18,
            "Flatcoin price should have decreased more than collateral price percentage decrease"
        );
    }
}
