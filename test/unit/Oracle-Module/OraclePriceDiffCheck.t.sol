// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract OraclePriceDiffCheckTest is OrderHelpers {
    uint256 collateralPrice = 1000e8;
    uint256 depositAmount = 100e18;
    uint256 positionMargin = 1e18;
    uint256 positionSize = 1e18;
    uint256 priceDiffPercent = 0.1e18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        setCollateralPrice(collateralPrice);

        oracleModProxy.setMaxDiffPercent(address(collateralAsset), 0.01e18); // 1% maximum difference between onchain and offchain price
    }

    function test_no_price_diff_error_viewer() public {
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        uint256 priceInUsd = viewer.getFlatcoinPriceInUSD();

        // Starting price of UNIT is $1 and it should remain the same.
        assertEq(priceInUsd, 1e18, "Incorrect price in USD with price difference");
    }

    function test_revert_price_diff_execute_deposit() public {
        // deposit a small amount so there is collateral in the system to trigger accounting on next deposit
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        announceStableDeposit(alice, depositAmount, mockKeeperFee.getKeeperFee());

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData);
    }

    function test_revert_price_diff_execute_withdrawal() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        announceStableWithdraw(alice, depositAmount, mockKeeperFee.getKeeperFee());

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData);
    }

    function test_revert_price_diff_execute_leverage_open() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        announceOpenLeverage(alice, positionMargin, positionSize, mockKeeperFee.getKeeperFee());

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData);
    }

    function test_revert_price_diff_execute_leverage_close() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: positionMargin,
            additionalSize: positionSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        announceCloseLeverage(alice, tokenId, mockKeeperFee.getKeeperFee());

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData);
    }

    function test_revert_price_diff_execute_leverage_adjust() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: positionMargin,
            additionalSize: positionSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        announceAdjustLeverage(alice, tokenId, 1e18, 1e18, mockKeeperFee.getKeeperFee());

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeOrder{value: 1}(alice, priceUpdateData);
    }

    function test_revert_price_diff_execute_limit_close() public {
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: positionMargin,
            additionalSize: positionSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        _createOraclePriceDiff();

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(900e8);

        uint256 newPriceDiffPercent = 200e18 / uint256(900);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, newPriceDiffPercent));
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);
    }

    function _createOraclePriceDiff() internal {
        vm.startPrank(admin);

        // Update Chainlink price
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, collateralPrice + 100e8, 0, block.timestamp, 0) // introduce a price difference
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);
    }
}
