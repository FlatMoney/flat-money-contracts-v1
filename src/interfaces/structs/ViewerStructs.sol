// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

struct LeveragePositionData {
    uint256 tokenId;
    uint256 averagePrice;
    uint256 marginDeposited;
    uint256 additionalSize;
    int256 entryCumulativeFunding;
    int256 profitLoss;
    int256 accruedFunding;
    int256 marginAfterSettlement;
    uint256 liquidationPrice;
    uint256 limitOrderStopLossPrice;
    uint256 limitOrderProfitTakePrice;
}
