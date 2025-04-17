// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {TokenArrayBuilder} from "../../../helpers/TokenArrayBuilder.sol";
import "../../../helpers/SwapperTestsHelper.sol";
import {MockGenerousRouter} from "../../../mocks/MockGenerousRouter.sol";

abstract contract SwapperSimpleAllowanceIntegrationTest is SwapperTestsHelper {
    using TokenArrayBuilder for *;

    function test_integration_swap_single_in_single_out_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC);
        Token memory destToken = rETH;

        runAllAggregatorTests({
            srcTokens: srcTokens,
            destToken: destToken,
            transferMethod: SwapperStructs.TransferMethod.ALLOWANCE
        });
    }

    function test_integration_swap_multi_in_single_out_simple_allowance() public {
        Token[] memory srcTokens = TokenArrayBuilder.fill(1, USDC).push(DAI);
        Token memory destToken = rETH;

        runAllAggregatorTests({
            srcTokens: srcTokens,
            destToken: destToken,
            transferMethod: SwapperStructs.TransferMethod.ALLOWANCE
        });
    }
}
