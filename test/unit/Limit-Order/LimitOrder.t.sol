// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract LimitOrderTest is OrderHelpers, ExpectRevert {
    uint256 tokenId;

    function setUp() public override {
        super.setUp();

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        vm.startPrank(admin);
        vaultProxy.setLeverageTradingFee(0.001e18); // 0.1%

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 10e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // second leverage position where tokenId > 0, to ensure proper checks later
        tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
    }

    function test_limit_order_modification() public {
        setCollateralPrice(1000e8);

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getLimitOrder(tokenId);
        DelayedOrderStructs.AnnouncedLimitClose memory limitClose = abi.decode(
            order.orderData,
            (DelayedOrderStructs.AnnouncedLimitClose)
        );

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.LimitClose));
        assertEq(limitClose.stopLossPrice, 900e18);
        assertEq(limitClose.profitTakePrice, 1100e18);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 950e18,
            profitTakePrice_: 1050e18
        });

        order = orderAnnouncementModProxy.getLimitOrder(tokenId);
        limitClose = abi.decode(order.orderData, (DelayedOrderStructs.AnnouncedLimitClose));

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.LimitClose));
        assertEq(limitClose.stopLossPrice, 950e18);
        assertEq(limitClose.profitTakePrice, 1050e18);
    }

    function test_limit_order_price_below_lower_threshold() public {
        uint256 collateralPrice = 899e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: collateralPrice
        });
    }

    function test_limit_order_price_equal_lower_threshold() public {
        uint256 collateralPrice = 900e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: collateralPrice
        });
    }

    function test_limit_order_price_equal_upper_threshold() public {
        uint256 collateralPrice = 1100e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: collateralPrice
        });
    }

    function test_limit_order_price_above_upper_threshold() public {
        uint256 collateralPrice = 1101e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            stopLossPrice: 900e18,
            profitTakePrice: 1100e18,
            oraclePrice: collateralPrice
        });
    }

    function test_limit_order_removal_after_position_close() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getLimitOrder(tokenId);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None));
        assertEq(order.keeperFee, 0);
        assertEq(order.executableAtTime, 0);
    }

    function test_limit_order_removal_after_position_liquidation() public {
        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        setCollateralPrice(750e8);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getLimitOrder(tokenId);

        assertEq(uint256(order.orderType), uint256(DelayedOrderStructs.OrderType.None));
        assertEq(order.keeperFee, 0);
        assertEq(order.executableAtTime, 0);
    }

    function test_limit_order_after_adjust() public {
        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        // Adjust position before executing limit order
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 10e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 traderCollateralBalanceBefore = collateralAsset.balanceOf(alice);

        setCollateralPrice(1200e8);

        LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenId);
        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        // The trade fee has increased because of the additional size adjustment
        uint256 tradeFee = (vaultProxy.leverageTradingFee() * position.additionalSize) / 1e18;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        vm.startPrank(keeper);

        bytes[] memory priceUpdateData = getPriceUpdateData(1200e8);
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            traderCollateralBalanceBefore + uint256(settledMargin) - tradeFee - keeperFee,
            collateralAsset.balanceOf(alice),
            "Trader collateralAsset balance incorrect after limit close execution"
        );
    }

    function test_adjust_limit_execution_delay() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint64 executableAtTime = uint64(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());

        assertEq(
            orderAnnouncementModProxy.getLimitOrder(tokenId).executableAtTime,
            executableAtTime,
            "Limit order execution time not updated correctly"
        );

        collateralPrice = 1101e8;
        setCollateralPrice(collateralPrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(
                OrderExecutionModule.executeLimitOrder.selector,
                tokenId,
                getPriceUpdateData(collateralPrice),
                0
            ),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.ExecutableTimeNotReached.selector, executableAtTime),
            value: 1
        });

        skip(orderAnnouncementModProxy.minExecutabilityAge());

        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, getPriceUpdateData(collateralPrice));
    }

    function test_revert_announce_limit_order() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                OrderAnnouncementModule.announceLimitOrder.selector,
                tokenId,
                1100e18,
                900e18
            ),
            expectedErrorSignature: "InvalidLimitOrderPrices(uint256,uint256)",
            errorData: abi.encodeWithSelector(OrderAnnouncementModule.InvalidLimitOrderPrices.selector, 1100e18, 900e18)
        });

        vm.startPrank(bob);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                OrderAnnouncementModule.announceLimitOrder.selector,
                tokenId,
                900e18,
                1100e18
            ),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(ICommonErrors.NotTokenOwner.selector, tokenId, address(bob))
        });
    }

    function test_revert_execute_limit_order() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        DelayedOrderStructs.Order memory order = orderAnnouncementModProxy.getLimitOrder(tokenId);

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            errorData: abi.encodeWithSelector(ICommonErrors.ExecutableTimeNotReached.selector, order.executableAtTime),
            value: 1
        });

        skip(1); // skip 1 second so that the new price update is valid
        bytes[] memory priceUpdateDataStale = getPriceUpdateData(899e8);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(
                OrderExecutionModule.executeLimitOrder.selector,
                tokenId,
                priceUpdateDataStale
            ),
            expectedErrorSignature: "PriceStale(uint8)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.PriceStale.selector,
                OracleModuleStructs.PriceSource.OffChain
            ),
            value: 1
        });

        // reverts when price > order stopLossPrice
        priceUpdateData = getPriceUpdateData(901e8);
        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "LimitOrderPriceNotInRange(uint256,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderExecutionModule.LimitOrderPriceNotInRange.selector,
                901e18,
                900e18,
                1100e18
            ),
            value: 1
        });

        // reverts when price < order profitTakePrice
        priceUpdateData = getPriceUpdateData(1099e8);
        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "LimitOrderPriceNotInRange(uint256,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                OrderExecutionModule.LimitOrderPriceNotInRange.selector,
                1099e18,
                900e18,
                1100e18
            ),
            value: 1
        });
    }

    function test_revert_reset_execution_authorized_module() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(OrderAnnouncementModule.resetExecutionTime.selector, tokenId),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_execute_adjust_order_but_limit_order_closed_the_position() public {
        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        setCollateralPrice(850e8);

        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: tokenId,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 5e18,
            keeperFeeAmount: 0
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        orderExecutionModProxy.executeLimitOrder{value: 1}({
            tokenId_: tokenId,
            priceUpdateData_: getPriceUpdateData(850e8)
        });

        assertEq(
            uint256(orderAnnouncementModProxy.getLimitOrder(tokenId).orderType),
            uint256(DelayedOrderStructs.OrderType.None)
        );
        assertEq(vaultProxy.getPosition(tokenId).additionalSize, 0);

        vm.startPrank(keeper);
        bytes[] memory priceUpdateData = getPriceUpdateData(850e8);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "OrderInvalid(address)",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderInvalid.selector, alice),
            value: 1
        });
    }

    function test_revert_execute_close_order_but_limit_order_closed_the_position() public {
        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        setCollateralPrice(850e8);

        announceCloseLeverage({traderAccount: alice, tokenId: tokenId, keeperFeeAmount: 0});

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        orderExecutionModProxy.executeLimitOrder{value: 1}({
            tokenId_: tokenId,
            priceUpdateData_: getPriceUpdateData(850e8)
        });

        assertEq(
            uint256(orderAnnouncementModProxy.getLimitOrder(tokenId).orderType),
            uint256(DelayedOrderStructs.OrderType.None)
        );
        assertEq(vaultProxy.getPosition(tokenId).additionalSize, 0);

        vm.startPrank(keeper);
        bytes[] memory priceUpdateData = getPriceUpdateData(850e8);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "OrderInvalid(address)",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderInvalid.selector, alice),
            value: 1
        });
    }

    function test_revert_limit_order_price_deviation() public {
        uint256 collateralPriceOriginal = 1000e8;
        uint256 collateralPricePyth = 1101e8;
        uint256 priceDiffPercent = ((collateralPricePyth - collateralPriceOriginal) * 1e18) / collateralPriceOriginal;

        vm.startPrank(admin);
        oracleModProxy.setMaxDiffPercent(address(collateralAsset), 0.01e18);

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPricePyth);

        vm.startPrank(keeper);

        vm.expectRevert(abi.encodeWithSelector(OracleModule.PriceMismatch.selector, priceDiffPercent));
        orderExecutionModProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);
    }

    function test_revert_announce_limit_order_when_global_margin_negative() public {
        // Since the default setUp function doesn't have favourable conditions for this test,
        // we refresh the environment to set up this test case.
        super.setUp();

        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit1 = 25e18;
        uint256 stableDeposit2 = 25e18;
        uint256 margin = 6e18;
        uint256 size = 60e18;

        setCollateralPrice(collateralPrice);

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit1,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: stableDeposit2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Skipping arbitrary number of days in order to replicate margin drain
        // due to funding fee settlements.
        skip(8 days);

        setCollateralPrice(collateralPrice);

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(
                OrderAnnouncementModule.announceLimitOrder.selector,
                tokenId,
                900e18,
                1100e18
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            errorData: abi.encodeWithSelector(FlatcoinVault.InsufficientGlobalMargin.selector)
        });
    }

    function test_revert_execute_limit_order_when_global_margin_negative() public {
        // Since the default setUp function doesn't have favourable conditions for this test,
        // we refresh the environment to set up this test case.
        super.setUp();

        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit1 = 25e18;
        uint256 stableDeposit2 = 25e18;
        uint256 margin = 6e18;
        uint256 size = 60e18;

        setCollateralPrice(collateralPrice);

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit1,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: stableDeposit2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(alice);

        orderAnnouncementModProxy.announceLimitOrder({
            tokenId_: tokenId,
            stopLossPrice_: 900e18,
            profitTakePrice_: 1100e18
        });

        // Skipping arbitrary number of days in order to replicate margin drain
        // due to funding fee settlements.
        skip(8 days);

        setCollateralPrice(collateralPrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(
                OrderExecutionModule.executeLimitOrder.selector,
                tokenId,
                getPriceUpdateData(collateralPrice)
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            errorData: abi.encodeWithSelector(FlatcoinVault.InsufficientGlobalMargin.selector),
            value: 1 wei
        });
    }

    function test_revert_setMinExecutabilityAge_when_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.setMinExecutabilityAge.selector, 1),
            expectedErrorSignature: "OnlyOwner(address)",
            ignoreErrorArguments: true
        });
    }

    function test_revert_when_executability_age_is_wrong() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.setMinExecutabilityAge.selector, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "minExecutabilityAge")
        });
    }
}
