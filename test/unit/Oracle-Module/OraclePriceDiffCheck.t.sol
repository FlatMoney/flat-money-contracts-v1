// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

import {LimitOrder} from "src/LimitOrder.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract OraclePriceDiffCheckTest is Setup, OrderHelpers {
    uint256 collateralPrice = 1000e8;
    uint256 depositAmount = 100e18;
    uint256 positionMargin = 1e18;
    uint256 positionSize = 1e18;
    uint256 priceDiffPercent = 0.1e18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        setWethPrice(collateralPrice);

        oracleModProxy.setMaxDiffPercent(0.01e18); // 1% maximum difference between onchain and offchain price
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
        assertEq(priceInUsd, 1000e18, "Incorrect price in USD with price difference");
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

        skip(uint256(vaultProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        delayedOrderProxy.executeOrder{value: 1}(alice, priceUpdateData);
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

        skip(uint256(vaultProxy.minExecutabilityAge())); // must reach minimum executability time

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        delayedOrderProxy.executeOrder{value: 1}(alice, priceUpdateData);
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

        skip(uint256(vaultProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        delayedOrderProxy.executeOrder{value: 1}(alice, priceUpdateData);
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

        skip(uint256(vaultProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        delayedOrderProxy.executeOrder{value: 1}(alice, priceUpdateData);
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

        skip(uint256(vaultProxy.minExecutabilityAge())); // must reach minimum executability time

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        delayedOrderProxy.executeOrder{value: 1}(alice, priceUpdateData);
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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        skip(uint256(vaultProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(900e8);

        uint256 newPriceDiffPercent = 200e18 / uint256(900);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, newPriceDiffPercent));
        limitOrderProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);
    }

    function _createOraclePriceDiff() internal {
        vm.startPrank(admin);

        // Update Chainlink price
        vm.mockCall(
            address(wethChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, collateralPrice + 100e8, 0, block.timestamp, 0) // introduce a price difference
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);
        oracleModProxy.updatePythPrice{value: 1}(msg.sender, priceUpdateData);
    }
}
