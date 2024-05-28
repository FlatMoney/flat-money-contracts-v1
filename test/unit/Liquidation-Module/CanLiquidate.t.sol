// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import "forge-std/console2.sol";

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "src/libraries/FlatcoinErrors.sol";
import {DecimalMath} from "../../../src/libraries/DecimalMath.sol";

contract CanLiquidateTest is Setup, OrderHelpers {
    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        FlatcoinStructs.OnchainOracle memory onchainOracle = FlatcoinStructs.OnchainOracle(
            wethChainlinkAggregatorV3,
            type(uint32).max // Effectively disable oracle expiry.
        );
        FlatcoinStructs.OffchainOracle memory offchainOracle = FlatcoinStructs.OffchainOracle(
            IPyth(address(mockPyth)),
            0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace,
            60, // max age of 60 seconds
            1000
        );

        oracleModProxy.setAssetAndOracles({
            _asset: address(WETH),
            _onchainOracle: onchainOracle,
            _offchainOracle: offchainOracle
        });

        oracleModProxy.setMaxDiffPercent(0.01e18); // 1% maximum difference between onchain and offchain price
    }

    function test_canLiquidate_using_custom_price_parameter() public {
        setWethPrice(1000e8);

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

        uint256 liqPrice = liquidationModProxy.liquidationPrice(0);

        assertFalse(
            liquidationModProxy.canLiquidate(tokenId, liqPrice + 5e18),
            "Leverage position should not be liquidatable"
        );

        assertTrue(
            liquidationModProxy.canLiquidate(tokenId, liqPrice - 1e18),
            "Leverage position should be liquidatable"
        );
    }

    function test_price_decrease_but_position_not_liquidatable() public {
        setWethPrice(1000e8);

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

        // Price goes down by 20%.
        // According to manual calculations, this shouldn't result in liquidation.
        setWethPrice(800e8);

        assertFalse(liquidationModProxy.canLiquidate(tokenId), "Leverage position should not be liquidatable");

        uint256 liqPrice = liquidationModProxy.liquidationPrice(tokenId);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setWethPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(tokenId), "Leverage position should be liquidatable");
    }

    function test_price_decrease_and_position_liquidatable() public {
        setWethPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = liquidationModProxy.liquidationPrice(0);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setWethPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
    }

    function test_price_increase_and_position_not_liquidatable() public {
        setWethPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        // Price goes up by 20%.
        setWethPrice(1200e8);

        assertFalse(liquidationModProxy.canLiquidate(0), "Leverage position should not be liquidatable");

        uint256 liqPrice = liquidationModProxy.liquidationPrice(0);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setWethPrice((liqPrice - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
    }

    // The test checks that funding rates are taken into account when checking if a position is liquidatable or not.
    function test_price_increase_but_position_liquidatable() public {
        vm.startPrank(alice);

        setWethPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 60e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // The market is skewed so we want to check the liquidation works with specific settings.
        // Note that this is the same as setting the maxFundingVelocity to 0.03e18 and the maxVelocitySkew to 1e18.
        vm.startPrank(admin);
        vaultProxy.setMaxFundingVelocity(0.006e18);
        vaultProxy.setMaxVelocitySkew(0.2e18);

        uint256 liqPriceBefore = liquidationModProxy.liquidationPrice(0);

        skip(13 days);

        uint256 liqPriceAfter = liquidationModProxy.liquidationPrice(0);

        assertTrue(liqPriceAfter > liqPriceBefore, "Liquidation price should increase");

        // Price goes up by 1%.
        setWethPrice(1010e8);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setWethPrice((liqPriceAfter - 1e18) / 1e10);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
    }

    function test_canLiquidate_price_divergence() public {
        setWethPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = liquidationModProxy.liquidationPrice(0);

        // Note: We are taking a margin of error here of $1 because of the approximation issues in the liquidation price.
        setWethPrice((liqPrice - 1e18) / 1e10);

        skip(1);

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(10e8); // the price difference is high
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        assertTrue(liquidationModProxy.canLiquidate(0), "Leverage position should be liquidatable");
    }

    function test_revert_liquidate_price_divergence() public {
        setWethPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(2 days);

        uint256 liqPrice = liquidationModProxy.liquidationPrice(0);

        uint256 onchainPrice = (liqPrice - 1e18) / 1e10;
        uint256 offchainPrice = (liqPrice - 50e18) / 1e10; // create a big price difference

        setWethPrice(onchainPrice);

        skip(1);

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(offchainPrice); // the price difference is high
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        uint256 priceDiff = onchainPrice > offchainPrice ? onchainPrice - offchainPrice : offchainPrice - onchainPrice;
        uint256 diffPercent = (priceDiff * 1e18) / (onchainPrice < offchainPrice ? onchainPrice : offchainPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, diffPercent));

        liquidationModProxy.liquidate(0);
    }
}
