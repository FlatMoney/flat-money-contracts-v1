// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../../helpers/ZapperHelpers.sol";
import "../../../helpers/AggregatorsAPIHelper.sol";
import "../../../helpers/ExpectRevert.sol";

abstract contract FlatZapperIntegrationTest is ZapperHelpers {
    function test_integration_zapper_rescue_funds() public {
        Token[] memory srcTokens = new Token[](1);
        srcTokens[0] = USDC;

        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        Aggregator[] memory aggregators = new Aggregator[](1);
        aggregators[0] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStruct, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: rETH,
            transferMethodIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        FlatZapper.AnnouncementData memory announcementData;
        {
            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            uint256 minAmountOut = (stableModProxy.stableDepositQuote(swapStruct.destData.minDestAmount - keeperFee) *
                (100 - DEFAULT_SLIPPAGE) *
                1e18) / 100e18;

            // Prepare the announcement data.
            bytes memory depositData = abi.encode(minAmountOut, keeperFee);

            announcementData = FlatZapper.AnnouncementData({
                orderType: DelayedOrderStructs.OrderType.StableDeposit,
                data: depositData
            });
        }

        vm.startPrank(bob);

        uint256 bobBalanceBefore = USDC.token.balanceOf(bob);

        // Bob transfers USDC directly instead of zapping.
        USDC.token.transfer(address(zapperProxy), 100e6);

        vm.startPrank(alice);

        // The zap shouldn't use the USDC that Bob transferred directly.
        zapperProxy.zap(swapStruct, announcementData);

        // Now let's rescue the funds.
        vm.startPrank(admin);

        zapperProxy.rescueFunds(USDC.token, bob, 100e6);

        assertEq(USDC.token.balanceOf(bob), bobBalanceBefore, "Bob's funds not rescued");
        assertEq(USDC.token.balanceOf(address(zapperProxy)), 0, "ZapperProxy still has USDC funds");
    }

    function test_integration_revert_zapper_when_using_wrongly_sent_funds() public {
        Token[] memory srcTokens = new Token[](2);
        srcTokens[0] = USDC;
        srcTokens[1] = DAI;

        Aggregator[] memory aggregators = new Aggregator[](2);
        aggregators[0] = Aggregator.ONE_INCH_V6;
        aggregators[1] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStructSimpleAllowance, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: rETH,
            transferMethodIndices: [int8(1), -1, -1],
            aggregators: aggregators
        });

        (SwapperStructs.InOutData memory swapStructPermit2, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: rETH,
            transferMethodIndices: [int8(-1), 1, -1],
            aggregators: aggregators
        });

        // The announcement data for both swapStructs will be equal as they only differ on the src token transfer method.
        FlatZapper.AnnouncementData memory announcementData;
        {
            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            uint256 minAmountOut = (stableModProxy.stableDepositQuote(
                swapStructSimpleAllowance.destData.minDestAmount - keeperFee
            ) *
                (100 - DEFAULT_SLIPPAGE) *
                1e18) / 100e18;

            // Prepare the announcement data.
            bytes memory depositData = abi.encode(minAmountOut, keeperFee);

            announcementData = FlatZapper.AnnouncementData({
                orderType: DelayedOrderStructs.OrderType.StableDeposit,
                data: depositData
            });
        }

        vm.startPrank(bob);

        // Bob transfers USDC and DAI directly instead of zapping.
        USDC.token.transfer(address(zapperProxy), 100e6);
        DAI.token.transfer(address(zapperProxy), 100e18);

        // Alice now tries to zap with the funds that Bob transferred.
        // She herself doesn't have any USDC or DAI.
        deal(address(USDC.token), alice, 0);
        deal(address(DAI.token), alice, 0);

        vm.startPrank(alice);

        vm.expectRevert("ERC20: transfer amount exceeds allowance");

        // The zap shouldn't use the USDC or DAI that Bob transferred directly.
        zapperProxy.zap(swapStructSimpleAllowance, announcementData);

        vm.expectRevert("TRANSFER_FROM_FAILED");

        zapperProxy.zap(swapStructPermit2, announcementData);
    }

    function test_integration_revert_zap_with_invalid_aggregator() public {
        Token[] memory srcTokens = new Token[](1);
        srcTokens[0] = USDC;

        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        Aggregator[] memory aggregators = new Aggregator[](1);
        aggregators[0] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStruct, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: rETH,
            transferMethodIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        for (uint256 i; i < swapStruct.srcData.length; ++i) {
            for (uint256 j; j < swapStruct.srcData[i].srcTokenSwapDetails.length; ++j) {
                swapStruct.srcData[i].srcTokenSwapDetails[j].aggregatorData = SwapperStructs.AggregatorData({
                    routerKey: bytes32("INVALID_ROUTER_KEY"),
                    swapData: swapStruct.srcData[i].srcTokenSwapDetails[j].aggregatorData.swapData
                });
            }
        }

        FlatZapper.AnnouncementData memory announcementData;
        uint256 minAmountOut;
        {
            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            minAmountOut =
                (stableModProxy.stableDepositQuote(swapStruct.destData.minDestAmount - keeperFee) *
                    (100 - DEFAULT_SLIPPAGE) *
                    1e18) /
                100e18;

            // Prepare the announcement data.
            bytes memory depositData = abi.encode(minAmountOut, keeperFee);

            announcementData = FlatZapper.AnnouncementData({
                orderType: DelayedOrderStructs.OrderType.StableDeposit,
                data: depositData
            });
        }

        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(RouterProcessor.InvalidAggregator.selector, (bytes32("INVALID_ROUTER_KEY")))
        );

        zapperProxy.zap(swapStruct, announcementData);
    }

    function test_integration_revert_zap_leverageOpen_when_swapped_amount_is_insufficient() public {
        Token[] memory srcTokens = new Token[](1);
        srcTokens[0] = USDC;

        uint256 oraclePrice = _getCollateralPrice();

        setCollateralPrice(oraclePrice);

        announceAndExecuteDeposit({
            traderAccount: admin,
            keeperAccount: keeper,
            depositAmount: srcTokens.length * DEFAULT_AMOUNT * 1e18,
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        Token memory destToken = rETH;
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        Aggregator[] memory aggregators = new Aggregator[](1);
        aggregators[0] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStruct, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: destToken,
            transferMethodIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        FlatZapper.LeverageOpenData memory leverageOpenData;
        {
            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            uint256 tradeFee = FeeManager(address(vaultProxy)).getTradeFee(
                _getSizeByAmountAndLeverage(srcTokens.length, 2)
            );
            uint256 minMargin = swapStruct.destData.minDestAmount - keeperFee - tradeFee;

            leverageOpenData = FlatZapper.LeverageOpenData({
                minMargin: minMargin + 1e18, // Adding 1e18 to make the margin insufficient.
                additionalSize: _getSizeByAmountAndLeverage(srcTokens.length, 2),
                maxFillPrice: (oraclePrice + 100) * 1e10, // Multiplying by 1e10 as the module expects price with 18 decimal places.
                stopLossPrice: 0,
                profitTakePrice: type(uint256).max,
                keeperFee: keeperFee
            });
        }

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(zapperProxy),
            callData: abi.encodeCall(
                FlatZapper.zap,
                (
                    swapStruct,
                    FlatZapper.AnnouncementData({
                        orderType: DelayedOrderStructs.OrderType.LeverageOpen,
                        data: abi.encode(leverageOpenData)
                    })
                )
            ),
            expectedErrorSignature: "AmountReceivedForMarginTooSmall(uint256,uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_integration_revert_zap_deposit_when_swapped_amount_is_insufficient_for_keeperFee() public {
        Token[] memory srcTokens = new Token[](1);
        srcTokens[0] = USDC;

        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        Aggregator[] memory aggregators = new Aggregator[](1);
        aggregators[0] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStruct, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: rETH,
            transferMethodIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        FlatZapper.AnnouncementData memory announcementData;
        {
            // Mocking the keeper fee to be 2e18.
            // Note that this test might fail is 1 ETH price is below `DEFAULT_AMOUNT` which is 1000.
            vm.mockCall(address(mockKeeperFee), abi.encodeWithSignature("getKeeperFee()"), abi.encode(2e18));

            uint256 keeperFee = mockKeeperFee.getKeeperFee();

            // Ignoring keeperFee accounting as the `NotEnoughCollateralAfterFees` error is thrown before the
            // `AmountReceivedForMarginTooSmall` error.
            uint256 minAmountOut = (stableModProxy.stableDepositQuote(swapStruct.destData.minDestAmount) *
                (100 - DEFAULT_SLIPPAGE) *
                1e18) / 100e18;

            // Prepare the announcement data.
            bytes memory depositData = abi.encode(minAmountOut, keeperFee);

            announcementData = FlatZapper.AnnouncementData({
                orderType: DelayedOrderStructs.OrderType.StableDeposit,
                data: depositData
            });
        }

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(zapperProxy),
            callData: abi.encodeCall(FlatZapper.zap, (swapStruct, announcementData)),
            expectedErrorSignature: "NotEnoughCollateralAfterFees(uint256,uint256)",
            ignoreErrorArguments: true
        });
    }

    function test_integration_revert_zap_leverageOpen_when_swapped_amount_is_insufficient_for_fees() public {
        Token memory destToken = rETH;

        Token[] memory srcTokens = new Token[](1);
        srcTokens[0] = USDC;

        uint256 oraclePrice = _getCollateralPrice();

        setCollateralPrice(oraclePrice);

        announceAndExecuteDeposit({
            traderAccount: admin,
            keeperAccount: keeper,
            depositAmount: srcTokens.length * getDefaultAmountInToken(destToken),
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        Aggregator[] memory aggregators = new Aggregator[](1);
        aggregators[0] = Aggregator.ONE_INCH_V6;

        (SwapperStructs.InOutData memory swapStruct, , ) = getSwapStruct({
            to: address(zapperProxy),
            srcTokens: srcTokens,
            destToken: destToken,
            transferMethodIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        FlatZapper.LeverageOpenData memory leverageOpenData;
        {
            // Mocking the keeper fee to be 2e18.
            // Note that this test might fail if 1 ETH price is below `DEFAULT_AMOUNT` which is 1000.
            vm.mockCall(address(mockKeeperFee), abi.encodeWithSignature("getKeeperFee()"), abi.encode(2e18));

            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            uint256 minMargin = swapStruct.destData.minDestAmount; // Notice that we are not subtracting the `keeperFee` and `tradeFee` here.

            leverageOpenData = FlatZapper.LeverageOpenData({
                minMargin: minMargin, // Adding 1e18 to make the margin insufficient.
                additionalSize: _getSizeByAmountAndLeverage(srcTokens.length, 2),
                maxFillPrice: (oraclePrice + 100) * 1e10, // Multiplying by 1e10 as the module expects price with 18 decimal places.
                stopLossPrice: 0,
                profitTakePrice: type(uint256).max,
                keeperFee: keeperFee
            });
        }

        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(zapperProxy),
            callData: abi.encodeCall(
                FlatZapper.zap,
                (
                    swapStruct,
                    FlatZapper.AnnouncementData({
                        orderType: DelayedOrderStructs.OrderType.LeverageOpen,
                        data: abi.encode(leverageOpenData)
                    })
                )
            ),
            expectedErrorSignature: "NotEnoughCollateralAfterFees(uint256,uint256)",
            ignoreErrorArguments: true
        });
    }
}
