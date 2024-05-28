// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {LimitOrder} from "src/LimitOrder.sol";
import {DelayedOrder} from "src/DelayedOrder.sol";
import {FlatcoinStructs} from "src/libraries/FlatcoinStructs.sol";
import {FlatcoinErrors} from "src/libraries/FlatcoinErrors.sol";
import {FlatcoinModuleKeys} from "src/libraries/FlatcoinModuleKeys.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract LimitOrderTest is OrderHelpers, ExpectRevert {
    uint256 tokenId;
    uint256 keeperFee;

    function setUp() public override {
        super.setUp();

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        keeperFee = mockKeeperFee.getKeeperFee();

        vm.startPrank(admin);
        leverageModProxy.setLeverageTradingFee(0.001e18); // 0.1%

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 10e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // second leverage position where tokenId > 0, to ensure proper checks later
        tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
    }

    function test_limit_order_modification() public {
        setWethPrice(1000e8);

        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        FlatcoinStructs.Order memory order = limitOrderProxy.getLimitOrder(tokenId);
        FlatcoinStructs.LimitClose memory limitClose = abi.decode(order.orderData, (FlatcoinStructs.LimitClose));

        assertTrue(leverageModProxy.isLockedByModule(tokenId, FlatcoinModuleKeys._LIMIT_ORDER_KEY));
        assertEq(uint256(order.orderType), uint256(FlatcoinStructs.OrderType.LimitClose));
        assertEq(limitClose.priceLowerThreshold, 900e18);
        assertEq(limitClose.priceUpperThreshold, 1100e18);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 950e18,
            priceUpperThreshold: 1050e18
        });

        order = limitOrderProxy.getLimitOrder(tokenId);
        limitClose = abi.decode(order.orderData, (FlatcoinStructs.LimitClose));

        assertTrue(leverageModProxy.isLockedByModule(tokenId, FlatcoinModuleKeys._LIMIT_ORDER_KEY));
        assertEq(uint256(order.orderType), uint256(FlatcoinStructs.OrderType.LimitClose));
        assertEq(limitClose.priceLowerThreshold, 950e18);
        assertEq(limitClose.priceUpperThreshold, 1050e18);
    }

    function test_limit_order_price_below_lower_threshold() public {
        uint256 collateralPrice = 899e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
    }

    function test_limit_order_price_equal_lower_threshold() public {
        uint256 collateralPrice = 900e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
    }

    function test_limit_order_price_equal_upper_threshold() public {
        uint256 collateralPrice = 1100e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
    }

    function test_limit_order_price_above_upper_threshold() public {
        uint256 collateralPrice = 1101e8;

        announceAndExecuteLimitClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
    }

    function test_limit_order_removal_after_position_close() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        FlatcoinStructs.Order memory order = limitOrderProxy.getLimitOrder(tokenId);

        assertEq(uint256(order.orderType), uint256(FlatcoinStructs.OrderType.None));
        assertEq(order.keeperFee, 0);
        assertEq(order.executableAtTime, 0);
    }

    function test_limit_order_removal_after_position_liquidation() public {
        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        setWethPrice(750e8);

        liquidationModProxy.liquidate(tokenId);

        FlatcoinStructs.Order memory order = limitOrderProxy.getLimitOrder(tokenId);

        assertEq(uint256(order.orderType), uint256(FlatcoinStructs.OrderType.None));
        assertEq(order.keeperFee, 0);
        assertEq(order.executableAtTime, 0);
    }

    function test_limit_order_after_adjust() public {
        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
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

        uint256 traderWethBalanceBefore = WETH.balanceOf(alice);

        setWethPrice(1200e8);

        FlatcoinStructs.Position memory position = vaultProxy.getPosition(tokenId);
        int256 settledMargin = leverageModProxy.getPositionSummary(tokenId).marginAfterSettlement;
        // The trade fee has increased because of the additional size adjustment
        uint256 tradeFee = (leverageModProxy.leverageTradingFee() * position.additionalSize) / 1e18;

        skip(uint256(vaultProxy.minExecutabilityAge()));

        vm.startPrank(keeper);

        bytes[] memory priceUpdateData = getPriceUpdateData(1200e8);
        limitOrderProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);

        assertEq(
            traderWethBalanceBefore + uint256(settledMargin) - tradeFee - keeperFee,
            WETH.balanceOf(alice),
            "Trader WETH balance incorrect after limit close execution"
        );
    }

    function test_adjust_limit_execution_delay() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
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

        uint64 executableAtTime = uint64(block.timestamp + vaultProxy.minExecutabilityAge());

        assertEq(
            limitOrderProxy.getLimitOrder(tokenId).executableAtTime,
            executableAtTime,
            "Limit order execution time not updated correctly"
        );

        collateralPrice = 1101e8;
        setWethPrice(collateralPrice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(
                LimitOrder.executeLimitOrder.selector,
                tokenId,
                getPriceUpdateData(collateralPrice),
                0
            ),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.ExecutableTimeNotReached.selector, executableAtTime),
            value: 1
        });

        skip(vaultProxy.minExecutabilityAge());

        limitOrderProxy.executeLimitOrder{value: 1}(tokenId, getPriceUpdateData(collateralPrice));
    }

    function test_revert_announce_limit_order() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.announceLimitOrder.selector, tokenId, 1100e18, 900e18),
            expectedErrorSignature: "InvalidThresholds(uint256,uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidThresholds.selector, 1100e18, 900e18)
        });

        vm.startPrank(bob);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.announceLimitOrder.selector, tokenId, 900e18, 1100e18),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.NotTokenOwner.selector, tokenId, address(bob))
        });
    }

    function test_revert_execute_limit_order() public {
        uint256 collateralPrice = 1000e8;

        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        FlatcoinStructs.Order memory order = limitOrderProxy.getLimitOrder(tokenId);

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPrice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "ExecutableTimeNotReached(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.ExecutableTimeNotReached.selector, order.executableAtTime),
            value: 1
        });

        skip(1); // skip 1 second so that the new price update is valid
        bytes[] memory priceUpdateDataStale = getPriceUpdateData(899e8);

        skip(uint256(vaultProxy.minExecutabilityAge()));

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.executeLimitOrder.selector, tokenId, priceUpdateDataStale),
            expectedErrorSignature: "PriceStale(uint8)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.PriceStale.selector, FlatcoinErrors.PriceSource.OffChain),
            value: 1
        });

        // reverts when price > order priceLowerThreshold
        priceUpdateData = getPriceUpdateData(901e8);
        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "LimitOrderPriceNotInRange(uint256,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                FlatcoinErrors.LimitOrderPriceNotInRange.selector,
                901e18,
                900e18,
                1100e18
            ),
            value: 1
        });

        // reverts when price < order priceUpperThreshold
        priceUpdateData = getPriceUpdateData(1099e8);
        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.executeLimitOrder.selector, tokenId, priceUpdateData),
            expectedErrorSignature: "LimitOrderPriceNotInRange(uint256,uint256,uint256)",
            errorData: abi.encodeWithSelector(
                FlatcoinErrors.LimitOrderPriceNotInRange.selector,
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
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.resetExecutionTime.selector, tokenId),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_execute_adjust_order_but_limit_order_closed_the_position() public {
        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        setWethPrice(850e8);

        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: tokenId,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 5e18,
            keeperFeeAmount: 0
        });

        skip(uint256(vaultProxy.minExecutabilityAge()));

        limitOrderProxy.executeLimitOrder{value: 1}({tokenId: tokenId, priceUpdateData: getPriceUpdateData(850e8)});

        assertEq(uint256(limitOrderProxy.getLimitOrder(tokenId).orderType), uint256(FlatcoinStructs.OrderType.None));
        assertEq(vaultProxy.getPosition(tokenId).additionalSize, 0);

        vm.startPrank(keeper);
        bytes[] memory priceUpdateData = getPriceUpdateData(850e8);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(DelayedOrder.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "ERC721NonexistentToken(uint256)",
            errorData: abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId),
            value: 1
        });
    }

    function test_revert_execute_close_order_but_limit_order_closed_the_position() public {
        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        setWethPrice(850e8);

        announceCloseLeverage({traderAccount: alice, tokenId: tokenId, keeperFeeAmount: 0});

        skip(uint256(vaultProxy.minExecutabilityAge()));

        limitOrderProxy.executeLimitOrder{value: 1}({tokenId: tokenId, priceUpdateData: getPriceUpdateData(850e8)});

        assertEq(uint256(limitOrderProxy.getLimitOrder(tokenId).orderType), uint256(FlatcoinStructs.OrderType.None));
        assertEq(vaultProxy.getPosition(tokenId).additionalSize, 0);

        vm.startPrank(keeper);
        bytes[] memory priceUpdateData = getPriceUpdateData(850e8);

        _expectRevertWithCustomError({
            target: address(delayedOrderProxy),
            callData: abi.encodeWithSelector(DelayedOrder.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "ERC721NonexistentToken(uint256)",
            errorData: abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId),
            value: 1
        });
    }

    function test_revert_limit_order_price_deviation() public {
        uint256 collateralPriceOriginal = 1000e8;
        uint256 collateralPricePyth = 1101e8;
        uint256 priceDiffPercent = ((collateralPricePyth - collateralPriceOriginal) * 1e18) / collateralPriceOriginal;

        vm.startPrank(admin);
        oracleModProxy.setMaxDiffPercent(0.01e18);

        vm.startPrank(alice);

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        skip(uint256(vaultProxy.minExecutabilityAge()));

        bytes[] memory priceUpdateData = getPriceUpdateData(collateralPricePyth);

        vm.startPrank(keeper);

        vm.expectRevert(abi.encodeWithSelector(FlatcoinErrors.PriceMismatch.selector, priceDiffPercent));
        limitOrderProxy.executeLimitOrder{value: 1}(tokenId, priceUpdateData);
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

        setWethPrice(collateralPrice);

        vm.startPrank(admin);

        vaultProxy.setMaxFundingVelocity(0.03e18);

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

        setWethPrice(collateralPrice);

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(LimitOrder.announceLimitOrder.selector, tokenId, 900e18, 1100e18),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InsufficientGlobalMargin.selector)
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

        setWethPrice(collateralPrice);

        vm.startPrank(admin);

        vaultProxy.setMaxFundingVelocity(0.03e18);

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

        limitOrderProxy.announceLimitOrder({
            tokenId: tokenId,
            priceLowerThreshold: 900e18,
            priceUpperThreshold: 1100e18
        });

        // Skipping arbitrary number of days in order to replicate margin drain
        // due to funding fee settlements.
        skip(8 days);

        setWethPrice(collateralPrice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(
                LimitOrder.executeLimitOrder.selector,
                tokenId,
                getPriceUpdateData(collateralPrice)
            ),
            expectedErrorSignature: "InsufficientGlobalMargin()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InsufficientGlobalMargin.selector),
            value: 1 wei
        });
    }
}
