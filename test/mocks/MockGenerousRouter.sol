// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/libraries/SwapperStructs.sol" as SwapperStructs;

/// @dev A dex aggregator router address which takes in less amount of tokens than provided
///      but returns the same amount as asked for.
contract MockGenerousRouter {
    /// @dev Percentage of the source tokens to take from the user.
    /// @dev 1e18 is 100%.
    uint128 public generousPercent;

    constructor(uint128 _generousPercent) {
        generousPercent = _generousPercent;
    }

    /// @dev Takes in multiple source tokens and returns the destination token.
    ///      The source token amount it takes is `srcAmount * generousPercent / 1e18`.
    function swap(
        SwapperStructs.SrcTokenSwapDetails memory srcTokenDetails,
        SwapperStructs.DestData memory destData
    ) external {
        srcTokenDetails.token.transferFrom(
            msg.sender,
            address(this),
            (generousPercent != 1e18) ? (srcTokenDetails.amount * generousPercent) / 1e18 : srcTokenDetails.amount
        );

        destData.destToken.transfer(msg.sender, destData.minDestAmount);
    }
}
