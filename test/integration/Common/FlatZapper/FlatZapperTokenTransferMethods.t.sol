// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../../helpers/ZapperHelpers.sol";
import "../../../helpers/AggregatorsAPIHelper.sol";
import "../../../helpers/ExpectRevert.sol";
import "../../../helpers/TokenArrayBuilder.sol";

abstract contract FlatZapperTokenTransferMethodsTests is ZapperHelpers {
    using TokenArrayBuilder for *;

    enum ZapAction {
        DEPOSIT,
        LEVERAGE_OPEN
    }

    function test_integration_zap_deposit_single_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), -1, -1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_single_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_single_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), -1, -1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_single_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_multi_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(1), -1, -1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_multi_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 1, -1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_multi_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(1), -1, -1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_multi_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 1, -1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_with_multi_in_using_diff_transfer_methods() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), 1, -1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_multi_in_using_diff_transfer_methods() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), 1, -1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_with_ETH_as_single_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), -1, 0];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_ETH_as_single_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), -1, 0];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_deposit_with_ETH_and_USDC_as_multi_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, 1];

        _test_builder(ZapAction.DEPOSIT, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpen_with_ETH_and_USDC_as_multi_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, 1];

        _test_builder(ZapAction.LEVERAGE_OPEN, srcTokens, transferMethodsIndices);
    }

    function test_integration_zap_leverageOpenWithLimits_with_single_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), -1, -1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_single_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, -1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_multi_in_using_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(1), -1, -1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_multi_in_using_permit2() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 1, -1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_multi_in_using_diff_transfer_methods() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(0), 1, -1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_ETH_as_single_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), -1, 0];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function test_integration_zap_leverageOpenWithLimits_with_ETH_and_USDC_as_multi_in() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(WETH);
        int8[TRANSFER_METHODS] memory transferMethodsIndices = [int8(-1), 0, 1];
        uint256 collateralPrice = _getCollateralPrice();

        _test_builder_leverage_with_limits(
            srcTokens,
            (collateralPrice * 99) / 100,
            (collateralPrice * 101) / 100,
            transferMethodsIndices
        );
    }

    function _test_builder(
        ZapAction zapAction,
        Token[] memory srcTokens,
        int8[TRANSFER_METHODS] memory transferMethodsIndices
    ) private {
        for (uint8 i; i < TRANSFER_METHODS; ++i) {
            uint256 snapshot = vm.snapshotState();

            Aggregator[] memory aggregators = new Aggregator[](srcTokens.length);
            for (uint256 j; j < srcTokens.length; ++j) {
                aggregators[j] = Aggregator.ONE_INCH_V6;
            }

            if (zapAction == ZapAction.DEPOSIT) {
                _createDepositOrder({
                    srcTokens: srcTokens,
                    transferMethodsIndices: transferMethodsIndices,
                    aggregators: aggregators
                });
            } else {
                _createLeverageOrder({
                    srcTokens: srcTokens,
                    transferMethodsIndices: transferMethodsIndices,
                    additionalSize: _getSizeByAmountAndLeverage(srcTokens.length, 2),
                    aggregators: aggregators
                });
            }

            vm.revertToState(snapshot);
        }
    }

    function _test_builder_leverage_with_limits(
        Token[] memory srcTokens,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        int8[TRANSFER_METHODS] memory transferMethodsIndices
    ) private {
        for (uint8 i; i < TRANSFER_METHODS; ++i) {
            uint256 snapshot = vm.snapshotState();

            Aggregator[] memory aggregators = new Aggregator[](srcTokens.length);
            for (uint256 j; j < srcTokens.length; ++j) {
                aggregators[j] = Aggregator.ONE_INCH_V6;
            }

            uint256 positionSize = _getSizeByAmountAndLeverage(srcTokens.length, 2);

            DelayedOrderStructs.Order memory order = _createLeverageOrder(
                CreateLeverageOrderData({
                    srcTokens: srcTokens,
                    transferMethodsIndices: transferMethodsIndices,
                    additionalSize: positionSize,
                    stopLossPrice: stopLossPrice,
                    profitTakePrice: profitTakePrice,
                    aggregators: aggregators
                })
            );

            DelayedOrderStructs.AnnouncedLeverageOpen memory announcedOrder = abi.decode(
                order.orderData,
                (DelayedOrderStructs.AnnouncedLeverageOpen)
            );

            assertEq(announcedOrder.stopLossPrice, stopLossPrice, "Invalid stopLossPrice");
            assertEq(announcedOrder.profitTakePrice, profitTakePrice, "Invalid profitTakePrice");

            vm.revertToState(snapshot);
        }
    }
}
