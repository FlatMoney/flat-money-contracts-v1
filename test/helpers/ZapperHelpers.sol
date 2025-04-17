// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "./ZapperSetup.sol";
import "./AggregatorsAPIHelper.sol";

import {IChainlinkAggregatorV3} from "../../src/interfaces/IChainlinkAggregatorV3.sol";

abstract contract ZapperHelpers is ZapperSetup {
    using SafeERC20 for IERC20;

    struct CreateLeverageOrderData {
        Token[] srcTokens;
        uint256 additionalSize;
        uint256 stopLossPrice;
        uint256 profitTakePrice;
        int8[TRANSFER_METHODS] transferMethodsIndices;
        Aggregator[] aggregators;
    }

    function _createDepositOrder(
        Token[] memory srcTokens,
        int8[TRANSFER_METHODS] memory transferMethodsIndices,
        Aggregator[] memory aggregators
    ) internal returns (DelayedOrderStructs.Order memory order) {
        // Setting the default collateral price to 1000e8.
        setCollateralPrice(1000e8);

        Token memory destToken = rETH;

        (
            SwapperStructs.InOutData memory swapStruct,
            SwapperStructs.SrcData[] memory srcDatas,
            SwapStructArrays memory swapStructArrays
        ) = getSwapStruct({
                to: address(zapperProxy),
                srcTokens: srcTokens,
                destToken: destToken,
                transferMethodIndices: transferMethodsIndices,
                aggregators: aggregators
            });

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

        for (uint8 i; i < srcDatas.length; ++i) {
            if (srcDatas[i].transferMethodData.method == SwapperStructs.TransferMethod.ALLOWANCE) {
                for (uint j; j < srcDatas[i].srcTokenSwapDetails.length; ++j) {
                    srcDatas[i].srcTokenSwapDetails[j].token.safeIncreaseAllowance(
                        address(zapperProxy),
                        srcDatas[i].srcTokenSwapDetails[j].amount
                    );
                }
            }
        }

        bool nativeSwapIncluded = transferMethodsIndices[uint8(SwapperStructs.TransferMethod.NATIVE)] != -1;

        if (nativeSwapIncluded) {
            // Get the amount of ETH to be sent along with calling the `swap` function.
            uint256 ethAmount = srcDatas[
                uint256(int256(transferMethodsIndices[uint8(SwapperStructs.TransferMethod.NATIVE)]))
            ].srcTokenSwapDetails[0].amount;

            uint256 ethBalanceBefore = alice.balance;

            zapperProxy.zap{value: ethAmount}(swapStruct, announcementData);

            // Check that the ETH balance of the caller has decreased by the amount sent.
            assertEq(alice.balance, ethBalanceBefore - ethAmount, "Alice's ETH balance incorrect");

            // Check that the ETH balance of the zapperProxy is 0 after swap.
            assertTrue(address(zapperProxy).balance == 0, "Swapper's ETH balance should be 0");
        } else {
            zapperProxy.zap(swapStruct, announcementData);
        }

        {
            order = orderAnnouncementModProxy.getAnnouncedOrder(alice);
            assertEq(
                uint256(order.orderType),
                uint256(DelayedOrderStructs.OrderType.StableDeposit),
                "Incorrect order type"
            );

            DelayedOrderStructs.AnnouncedStableDeposit memory depositAnnouncementData = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedStableDeposit)
            );

            // srcTokens balance check.
            for (uint8 i; i < srcTokens.length; ++i) {
                // If native swap is included and the source token is WETH, then skip the balance check.
                // Note: The balance check for WETH should be done somewhere upstream in case the multi swap is done with WETH as one of the source tokens.
                if (nativeSwapIncluded && address(srcTokens[i].token) == address(WETH.token)) {
                    continue;
                }

                assertEq(
                    swapStructArrays.srcTokens[i].token.balanceOf(alice),
                    swapStructArrays.priorSrcBalances[i] - swapStructArrays.srcAmounts[i],
                    "Alice's src balance incorrect"
                );
                assertTrue(
                    swapStructArrays.srcTokens[i].token.balanceOf(address(zapperProxy)) == 0,
                    "Zapper's src balance should be 0"
                );
            }

            assertEq(depositAnnouncementData.minAmountOut, minAmountOut, "Incorrect minAmount");

            assertGe(
                depositAnnouncementData.depositAmount,
                (swapStruct.destData.minDestAmount * (100 - DEFAULT_SLIPPAGE) * 1e18) / 100e18,
                "Deposit amount is less than expected"
            );
        }
    }

    function _createLeverageOrder(
        Token[] memory srcTokens,
        uint256 additionalSize,
        int8[TRANSFER_METHODS] memory transferMethodsIndices,
        Aggregator[] memory aggregators
    ) internal returns (DelayedOrderStructs.Order memory order) {
        return
            _createLeverageOrder(srcTokens, additionalSize, 0, type(uint256).max, transferMethodsIndices, aggregators);
    }

    function _createLeverageOrder(
        Token[] memory srcTokens,
        uint256 additionalSize,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        int8[TRANSFER_METHODS] memory transferMethodsIndices,
        Aggregator[] memory aggregators
    ) internal returns (DelayedOrderStructs.Order memory order) {
        CreateLeverageOrderData memory data = CreateLeverageOrderData({
            srcTokens: srcTokens,
            additionalSize: additionalSize,
            stopLossPrice: stopLossPrice,
            profitTakePrice: profitTakePrice,
            transferMethodsIndices: transferMethodsIndices,
            aggregators: aggregators
        });

        return _createLeverageOrder(data);
    }

    function _createLeverageOrder(
        CreateLeverageOrderData memory data
    ) internal returns (DelayedOrderStructs.Order memory order) {
        Token memory destToken = rETH;
        uint256 oraclePrice = _getCollateralPrice();

        setCollateralPrice(oraclePrice);

        announceAndExecuteDeposit({
            traderAccount: admin,
            keeperAccount: keeper,
            depositAmount: data.srcTokens.length * getDefaultAmountInToken(destToken),
            oraclePrice: oraclePrice,
            keeperFeeAmount: 0
        });

        (
            SwapperStructs.InOutData memory swapStruct,
            SwapperStructs.SrcData[] memory srcDatas,
            SwapStructArrays memory swapStructArrays
        ) = getSwapStruct({
                to: address(zapperProxy),
                srcTokens: data.srcTokens,
                destToken: destToken,
                transferMethodIndices: data.transferMethodsIndices,
                aggregators: data.aggregators
            });

        FlatZapper.LeverageOpenData memory leverageOpenData;
        {
            uint256 keeperFee = mockKeeperFee.getKeeperFee();
            uint256 minMargin = ((swapStruct.destData.minDestAmount - keeperFee) * 0.995e18) / 1e18; // Taking an error margin of 0.5%

            leverageOpenData = FlatZapper.LeverageOpenData({
                minMargin: minMargin,
                additionalSize: data.additionalSize,
                maxFillPrice: (oraclePrice + 100) * 1e10, // Multiplying by 1e10 as the module expects price with 18 decimal places.
                stopLossPrice: data.stopLossPrice,
                profitTakePrice: data.profitTakePrice,
                keeperFee: keeperFee
            });
        }

        vm.startPrank(alice);

        for (uint8 i; i < srcDatas.length; ++i) {
            if (srcDatas[i].transferMethodData.method == SwapperStructs.TransferMethod.ALLOWANCE) {
                for (uint j; j < srcDatas[i].srcTokenSwapDetails.length; ++j) {
                    srcDatas[i].srcTokenSwapDetails[j].token.safeIncreaseAllowance(
                        address(zapperProxy),
                        srcDatas[i].srcTokenSwapDetails[j].amount
                    );
                }
            }
        }

        bool nativeSwapIncluded = data.transferMethodsIndices[uint8(SwapperStructs.TransferMethod.NATIVE)] != -1;

        if (nativeSwapIncluded) {
            // Get the amount of ETH to be sent along with calling the `swap` function.
            uint256 ethAmount = srcDatas[
                uint256(int256(data.transferMethodsIndices[uint8(SwapperStructs.TransferMethod.NATIVE)]))
            ].srcTokenSwapDetails[0].amount;

            uint256 ethBalanceBefore = alice.balance;

            zapperProxy.zap{value: ethAmount}(
                swapStruct,
                FlatZapper.AnnouncementData({
                    orderType: DelayedOrderStructs.OrderType.LeverageOpen,
                    data: abi.encode(leverageOpenData)
                })
            );

            // Check that the ETH balance of the caller has decreased by the amount sent.
            assertEq(alice.balance, ethBalanceBefore - ethAmount, "Alice's ETH balance incorrect");

            // Check that the ETH balance of the zapperProxy is 0 after swap.
            assertTrue(address(zapperProxy).balance == 0, "Swapper's ETH balance should be 0");
        } else {
            zapperProxy.zap(
                swapStruct,
                FlatZapper.AnnouncementData({
                    orderType: DelayedOrderStructs.OrderType.LeverageOpen,
                    data: abi.encode(leverageOpenData)
                })
            );
        }

        {
            order = orderAnnouncementModProxy.getAnnouncedOrder(alice);
            assertEq(
                uint256(order.orderType),
                uint256(DelayedOrderStructs.OrderType.LeverageOpen),
                "Incorrect order type"
            );

            DelayedOrderStructs.AnnouncedLeverageOpen memory leverageOpenAnnouncementData = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedLeverageOpen)
            );

            // srcTokens balance check.
            for (uint8 i; i < data.srcTokens.length; ++i) {
                // If native swap is included and the source token is WETH, then skip the balance check.
                // Note: The balance check for WETH should be done somewhere upstream in case the multi swap is done with WETH as one of the source tokens.
                if (nativeSwapIncluded && address(data.srcTokens[i].token) == address(WETH.token)) {
                    continue;
                }

                assertEq(
                    swapStructArrays.srcTokens[i].token.balanceOf(alice),
                    swapStructArrays.priorSrcBalances[i] - swapStructArrays.srcAmounts[i],
                    "Alice's src balance incorrect"
                );
                assertTrue(
                    swapStructArrays.srcTokens[i].token.balanceOf(address(zapperProxy)) == 0,
                    "Zapper's src balance should be 0"
                );
            }

            assertGe(leverageOpenAnnouncementData.margin, leverageOpenData.minMargin, "Incorrect margin");
            assertEq(leverageOpenAnnouncementData.additionalSize, data.additionalSize, "Incorrect additional size");
            assertEq(
                leverageOpenAnnouncementData.maxFillPrice,
                leverageOpenData.maxFillPrice,
                "Incorrect max fill price"
            );
            assertEq(leverageOpenAnnouncementData.stopLossPrice, data.stopLossPrice, "Incorrect price lower threshold");
            assertEq(
                leverageOpenAnnouncementData.profitTakePrice,
                data.profitTakePrice,
                "Incorrect price upper threshold"
            );
        }
    }

    function _getSizeByAmountAndLeverage(uint256 numSrcTokens, uint256 leverage) internal view returns (uint256 size) {
        uint256 oraclePrice = _getCollateralPrice();

        // This is equivalent to doing the following calculation:
        // We are assuming that chainlink price returns with 8 decimal places.
        // We multiply the srcAmount by 1e18 to get the amount with 18 decimal places.
        // => margin = (srcAmount * 1e18 / 10**decimals)  / (oraclePrice / 1e8)
        // => leverage = (margin + additional_size) / margin
        // => additional_size = (leverage * margin) - margin
        // => additional_size = (leverage - 1) * margin
        // => additional_size = (leverage - 1) * (srcAmount * 1e18 / 10**decimals) / (oraclePrice / 1e8)

        return (numSrcTokens * (DEFAULT_AMOUNT * (leverage - 1) * 1e26)) / oraclePrice;
    }

    function _getCollateralPrice() internal view returns (uint256) {
        (, int256 price, , , ) = rETH.priceFeed.latestRoundData();

        assert(price > 0);

        return uint256(price);
    }
}
