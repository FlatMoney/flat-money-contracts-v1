// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "../interfaces/structs/ViewerStructs.sol" as ViewerStructs;
import "../interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "../interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

interface IViewer {
    function getAccountLeveragePositionData(
        address account
    ) external view returns (ViewerStructs.LeveragePositionData[] memory positionData);

    function getPositionData(
        uint256 tokenIdFrom,
        uint256 tokenIdTo
    ) external view returns (ViewerStructs.LeveragePositionData[] memory positionData);

    function getPositionData(
        uint256 tokenId
    ) external view returns (ViewerStructs.LeveragePositionData memory positionData);

    function getFlatcoinTVL() external view returns (uint256 tvl);

    function getMarketSummary() external view returns (LeverageModuleStructs.MarketSummary memory marketSummary);

    function getMarketSummary(
        uint256 price
    ) external view returns (LeverageModuleStructs.MarketSummary memory marketSummary);

    function getVaultSummary() external view returns (FlatcoinVaultStructs.VaultSummary memory vaultSummary);

    function getMarketSkewPercentage() external view returns (int256 skewPercent);

    function getFlatcoinPriceInUSD() external view returns (uint256 priceInUSD);

    /// @dev Note that the liquidation price for an options market is not defined.
    function liquidationPrice(uint256 tokenId) external view returns (uint256 liqPrice);

    /// @dev Note that the liquidation price for an options market is not defined.
    function liquidationPrice(uint256 tokenId, uint256 marketPrice) external view returns (uint256 liqPrice);
}
