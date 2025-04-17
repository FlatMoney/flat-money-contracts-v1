// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IChainlinkAggregatorV3} from "../interfaces/IChainlinkAggregatorV3.sol";

/// @title USD cross ETH price aggregator.
/// @notice Converts ETH denominated oracle to USD denominated oracle.
/// @dev This must implement Chainlink aggregator interface.
contract ETHCrossAggregator is IChainlinkAggregatorV3 {
    error TokenToEthPriceStale(uint256 tokenToEthUpdatedAt);

    address public token;
    IChainlinkAggregatorV3 public tokenToEthAggregator;
    IChainlinkAggregatorV3 public ethToUsdAggregator;
    uint256 public tokenToEthPriceMaxAge;

    /// @dev Mind the decimals of aggregator prices, eg ETH/USD has 8 decimals while rETH/ETH has 18 decimals.
    /// @param token_ Token to get USD price for, eg rETH.
    /// @param tokenToEthAggregator_ Chainlink aggregator for token to ETH price, eg rETH/ETH.
    /// @param ethToUsdAggregator_ Chainlink aggregator for ETH to USD price.
    /// @param tokenToEthPriceMaxAge_ Maximum age of token to ETH price in seconds, eg 25 hours.
    constructor(
        address token_,
        IChainlinkAggregatorV3 tokenToEthAggregator_,
        IChainlinkAggregatorV3 ethToUsdAggregator_,
        uint256 tokenToEthPriceMaxAge_
    ) {
        token = token_;
        tokenToEthAggregator = tokenToEthAggregator_;
        ethToUsdAggregator = ethToUsdAggregator_;
        tokenToEthPriceMaxAge = tokenToEthPriceMaxAge_;
    }

    /// @return roundId_ The round ID.
    /// @return answer_ The price in USD (price decimal: 8)
    /// @return startedAt_ Timestamp of when the round started.
    /// @return updatedAt_ Timestamp of when the round was updated.
    /// @return answeredInRound_ The round ID of the round in which the answer was computed.
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId_, int256 answer_, uint256 startedAt_, uint256 updatedAt_, uint80 answeredInRound_)
    {
        (, int256 tokenToEthPrice, , uint256 tokenToEthUpdatedAt, ) = tokenToEthAggregator.latestRoundData();
        (, int256 ethToUsdPrice, , uint256 ethToUsdUpdatedAt, ) = ethToUsdAggregator.latestRoundData();

        // Need to check if rETH/ETH price was updated in past 25 hours, because ETH/USD has shorter heartbeat (20 minutes compared to rETH/ETH's 24 hours).
        if (block.timestamp > tokenToEthUpdatedAt + tokenToEthPriceMaxAge)
            revert TokenToEthPriceStale(tokenToEthUpdatedAt);

        // Given that ETH/USD heartbeat is shorter, in most of the cases ethToUsdUpdatedAt will be returned (latest).
        // If not for the revert above, we would not see if received rETH/ETH price is stale.
        // If updatedAt appears to be stale, it will revert down the stream in OracleModule
        updatedAt_ = tokenToEthUpdatedAt < ethToUsdUpdatedAt ? ethToUsdUpdatedAt : tokenToEthUpdatedAt;

        // tokenToEthPrice has 18 decimals, ethToUsdPrice has 8 decimals.
        answer_ = (tokenToEthPrice * ethToUsdPrice) / 1e18;

        return (roundId_, answer_, startedAt_, updatedAt_, answeredInRound_);
    }

    function decimals() external pure override returns (uint8 decimals_) {
        decimals_ = 8;
    }
}
