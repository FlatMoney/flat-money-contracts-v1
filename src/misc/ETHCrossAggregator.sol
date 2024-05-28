// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

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
    /// @param _token Token to get USD price for, eg rETH.
    /// @param _tokenToEthAggregator Chainlink aggregator for token to ETH price, eg rETH/ETH.
    /// @param _ethToUsdAggregator Chainlink aggregator for ETH to USD price.
    /// @param _tokenToEthPriceMaxAge Maximum age of token to ETH price in seconds, eg 25 hours.
    constructor(
        address _token,
        IChainlinkAggregatorV3 _tokenToEthAggregator,
        IChainlinkAggregatorV3 _ethToUsdAggregator,
        uint256 _tokenToEthPriceMaxAge
    ) {
        token = _token;
        tokenToEthAggregator = _tokenToEthAggregator;
        ethToUsdAggregator = _ethToUsdAggregator;
        tokenToEthPriceMaxAge = _tokenToEthPriceMaxAge;
    }

    /// @return roundId The round ID.
    /// @return answer The price in USD (price decimal: 8)
    /// @return startedAt Timestamp of when the round started.
    /// @return updatedAt Timestamp of when the round was updated.
    /// @return answeredInRound The round ID of the round in which the answer was computed.
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 tokenToEthPrice, , uint256 tokenToEthUpdatedAt, ) = tokenToEthAggregator.latestRoundData();
        (, int256 ethToUsdPrice, , uint256 ethToUsdUpdatedAt, ) = ethToUsdAggregator.latestRoundData();

        // Need to check if rETH/ETH price was updated in past 25 hours, because ETH/USD has shorter heartbeat (20 minutes compared to rETH/ETH's 24 hours).
        if (block.timestamp > tokenToEthUpdatedAt + tokenToEthPriceMaxAge)
            revert TokenToEthPriceStale(tokenToEthUpdatedAt);

        // Given that ETH/USD heartbeat is shorter, in most of the cases ethToUsdUpdatedAt will be returned (latest).
        // If not for the revert above, we would not see if received rETH/ETH price is stale.
        // If updatedAt appears to be stale, it will revert down the stream in OracleModule
        updatedAt = tokenToEthUpdatedAt < ethToUsdUpdatedAt ? ethToUsdUpdatedAt : tokenToEthUpdatedAt;

        // tokenToEthPrice has 18 decimals, ethToUsdPrice has 8 decimals.
        answer = (tokenToEthPrice * ethToUsdPrice) / 1e18;

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function decimals() external pure override returns (uint8 decimals_) {
        decimals_ = 8;
    }
}
