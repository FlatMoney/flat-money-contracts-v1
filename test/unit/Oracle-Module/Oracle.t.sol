// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract OracleTest is OrderHelpers, ExpectRevert {
    function test_oracle_get_price_full_update() public {
        uint256 wethPrice = 2200e8;
        // update onchain and offchain price
        setCollateralPrice(wethPrice);
        skip(10);

        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice(address(vaultProxy.collateral()));
        assertEq(price, wethPrice * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp - 10, "Invalid timestamp");
    }

    function test_oracle_get_price_onchain_update() public {
        uint256 wethPriceOld = 1500e8;
        uint256 wethPriceNew = 2500e8;

        setCollateralPrice(wethPriceOld);

        skip(1);

        // Update collateralAsset price on Chainlink only
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, wethPriceNew, 0, block.timestamp, 0)
        );

        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice(address(vaultProxy.collateral())); // should return the Chainlink price because it's fresher
        assertEq(price, wethPriceNew * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp, "Invalid timestamp");
    }

    function test_oracle_get_price_offchain_update() public {
        uint256 wethPriceOld = 1000e8;
        uint256 wethPriceNew = 1500e8;

        setCollateralPrice(wethPriceOld);

        skip(1);

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceNew);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice(address(vaultProxy.collateral()));
        assertEq(price, wethPriceNew * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp, "Invalid timestamp");
    }

    // Should return the Offchain price if both onchain and offchain prices have the same timestamp
    function test_oracle_get_price_difference() public {
        uint256 wethPriceOnchain = 2499e8;
        uint256 wethPriceOffchain = 2500e8;

        skip(1);

        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice(address(vaultProxy.collateral()));
        assertEq(price, wethPriceOffchain * 1e10, "Invalid oracle price"); // should return the offchain price, not onchain
        assertEq(timestamp, block.timestamp, "Invalid timestamp");
    }

    function test_oracle_get_price_max_age() public {
        uint256 wethPrice = 2500e8;

        setCollateralPrice(wethPrice);

        skip(1);

        address marketToken = address(vaultProxy.collateral());

        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice({
            asset_: marketToken,
            maxAge_: 5,
            priceDiffCheck_: true
        });
        assertEq(price, wethPrice * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp - 1, "Invalid timestamp");

        skip(5);

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.PriceStale.selector, OracleModuleStructs.PriceSource.OffChain)
        );
        (price, timestamp) = oracleModProxy.getPrice({asset_: marketToken, maxAge_: 5, priceDiffCheck_: true});

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(wethPrice);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        (price, timestamp) = oracleModProxy.getPrice({asset_: marketToken, maxAge_: 5, priceDiffCheck_: true});
        assertEq(price, wethPrice * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp, "Invalid timestamp");

        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, wethPrice, 0, block.timestamp, 0)
        );

        (price, timestamp) = oracleModProxy.getPrice({asset_: marketToken, maxAge_: 5, priceDiffCheck_: true});
        assertEq(price, wethPrice * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp, "Invalid timestamp");
    }

    function test_oracle_price_mismatch() public {
        vm.startPrank(admin);
        oracleModProxy.setMaxDiffPercent(address(collateralAsset), 0.01e18); // 1% maximum difference between onchain and offchain price

        // Lower and within 1% - should pass
        {
            uint256 wethPriceOnchain = 1010e8;
            uint256 wethPriceOffchain = 1000e8;

            skip(1);

            // Update Chainlink price
            vm.mockCall(
                address(collateralChainlinkAggregatorV3),
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
            );

            // Update Pyth network price
            bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
            oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

            oracleModProxy.getPrice({asset_: address(vaultProxy.collateral()), maxAge_: 100, priceDiffCheck_: true});
        }

        // Lower and outside 1% - should revert
        {
            uint256 wethPriceOnchain = 1011e8;
            uint256 wethPriceOffchain = 1000e8;
            uint256 priceDiffPercent = 0.011e18; // 1.1%

            skip(1);

            // Update Chainlink price
            vm.mockCall(
                address(collateralChainlinkAggregatorV3),
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
            );

            // Update Pyth network price
            bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
            oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

            address marketToken = address(vaultProxy.collateral());

            oracleModProxy.getPrice({asset_: marketToken, maxAge_: 100, priceDiffCheck_: false}); // explicit test of the priceDiffCheck logic

            vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
            oracleModProxy.getPrice({asset_: marketToken, maxAge_: 100, priceDiffCheck_: true});
        }

        // Higher and within 1% - should pass
        {
            uint256 wethPriceOnchain = 1000e8;
            uint256 wethPriceOffchain = 1010e8;

            skip(1);

            // Update Chainlink price
            vm.mockCall(
                address(collateralChainlinkAggregatorV3),
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
            );

            // Update Pyth network price
            bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
            oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

            oracleModProxy.getPrice({asset_: address(vaultProxy.collateral()), maxAge_: 100, priceDiffCheck_: true});
        }

        // Higher and outside 1% - should revert
        {
            uint256 wethPriceOnchain = 1000e8;
            uint256 wethPriceOffchain = 1011e8;
            uint256 priceDiffPercent = 0.011e18; // 1.1%

            skip(1);

            // Update Chainlink price
            vm.mockCall(
                address(collateralChainlinkAggregatorV3),
                abi.encodeWithSignature("latestRoundData()"),
                abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
            );

            // Update Pyth network price
            bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
            oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

            address marketToken = address(vaultProxy.collateral());

            vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
            oracleModProxy.getPrice({asset_: marketToken, maxAge_: 100, priceDiffCheck_: true});
        }
    }

    function test_oracle_return_onchain_if_offchain_invalid() public {
        vm.prank(admin);
        // 1% maximum difference between onchain and offchain price
        oracleModProxy.setMaxDiffPercent(address(collateralAsset), 0.01e18);

        // First set both prices to be the same
        setCollateralPrice(1000e8);

        // Then update the prices, but make the Pyth price to be invalid
        skip(1);
        uint256 onchainPriceNew = 2000e8;
        uint256 offchainPriceNew = 1600e8;
        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, onchainPriceNew, 0, block.timestamp, 0)
        );
        // Update Pyth network price
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = mockPyth.createPriceFeedUpdateData(
            0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace,
            int64(uint64(offchainPriceNew)),
            uint64(offchainPriceNew) / 10_000,
            8, // setting invalid expo value (positive instead of negative)
            int64(uint64(offchainPriceNew)),
            uint64(offchainPriceNew) / 10_000,
            uint64(block.timestamp)
        );
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        // Should return the Chainlink price because Pyth price is invalid and not revert
        (uint256 price, uint256 timestamp) = oracleModProxy.getPrice(address(vaultProxy.collateral()));
        assertEq(price, onchainPriceNew * 1e10, "Invalid oracle price");
        assertEq(timestamp, block.timestamp, "Invalid timestamp");
    }

    function test_oracle_revert_if_onchain_invalid() public {
        skip(1);
        int256 onchainPrice = -2000e8;
        uint256 offchainPrice = 1600e8;

        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, onchainPrice, 0, block.timestamp, 0)
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(offchainPrice);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        address marketToken = address(vaultProxy.collateral());

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.PriceInvalid.selector, OracleModuleStructs.PriceSource.OnChain)
        );
        oracleModProxy.getPrice(marketToken);
    }

    function test_oracle_calculate_price_difference_correctly() public {
        vm.startPrank(admin);
        // 0.5% maximum difference between onchain and offchain price
        oracleModProxy.setMaxDiffPercent(address(collateralAsset), 0.005e18);

        uint256 wethPriceOnchain = 4e8;
        uint256 wethPriceOffchain = 2e8;
        uint256 priceDiffPercent = 1e18;

        skip(1);

        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, wethPriceOnchain, 0, block.timestamp, 0)
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(wethPriceOffchain);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);

        address marketToken = address(vaultProxy.collateral());

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        oracleModProxy.getPrice({asset_: marketToken, maxAge_: 100, priceDiffCheck_: true});
    }

    function test_multiple_prices_in_same_tx() public {
        // Setup
        vm.startPrank(admin);
        vaultProxy.setLeverageTradingFee(0.001e18); // 0.1%
        uint256 collateralPrice = 1000e8;
        setCollateralPrice(collateralPrice);
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 10000e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Create small leverage position
        uint256 initialMargin = 0.05e18;
        uint256 initialSize = 0.1e18;
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: initialMargin,
            additionalSize: initialSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Announce leverage adjustment
        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: tokenId,
            marginAdjustment: 100e18,
            additionalSizeAdjustment: 2400e18,
            keeperFeeAmount: 0
        });

        // Anounce limit order in the same block
        vm.startPrank(alice);
        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 0,
            profitTakePrice_: 1 // executable at any price
        });

        // Wait for the orders to be executable
        skip(orderAnnouncementModProxy.minExecutabilityAge());
        bytes[] memory priceUpdateData1 = getPriceUpdateData(collateralPrice);
        // Price increases slightly after one second
        skip(1);
        bytes[] memory priceUpdateData2 = getPriceUpdateData(collateralPrice + 1.2e8);

        // Execute the adjustment with the lower price and the limit order with the higher price
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData1);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(
                OrderExecutionModule.executeLimitOrder.selector,
                tokenId,
                priceUpdateData2,
                0
            ),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.ExecutableTimeNotReached.selector,
                uint64(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge())
            ),
            value: 1
        });
    }
}
