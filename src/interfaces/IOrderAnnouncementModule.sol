// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "./structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

interface IOrderAnnouncementModule {
    // solhint-disable-next-line func-name-mixedcase
    function minDepositAmountUSD() external view returns (uint256 minStableDeposit);

    function minExecutabilityAge() external view returns (uint64 minExecutabilityAge);

    function authorizedCallers(address caller) external view returns (bool isAuthorized);

    function announceStableDeposit(uint256 depositAmount, uint256 minAmountOut, uint256 keeperFee) external;

    function announceLeverageOpen(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 keeperFee
    ) external;

    function announceLeverageOpenWithLimits(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFee
    ) external;

    function announceStableDepositFor(
        uint256 depositAmount,
        uint256 minAmountOut,
        uint256 keeperFee,
        address receiver
    ) external;

    function announceStableWithdraw(uint256 withdrawAmount, uint256 minAmountOut, uint256 keeperFee) external;

    function announceLeverageOpenFor(
        uint256 margin,
        uint256 additionalSize,
        uint256 maxFillPrice,
        uint256 stopLossPrice,
        uint256 profitTakePrice,
        uint256 keeperFee,
        address receiver
    ) external;

    function announceLeverageAdjust(
        uint256 tokenId,
        int256 marginAdjustment,
        int256 additionalSizeAdjustment,
        uint256 fillPrice,
        uint256 keeperFee
    ) external;

    function announceLeverageClose(uint256 tokenId, uint256 minFillPrice, uint256 keeperFee) external;

    function announceLimitOrder(uint256 tokenId, uint256 stopLossPrice, uint256 profitTakePrice) external;

    function cancelLimitOrder(uint256 tokenId) external;

    function createLimitOrder(
        uint256 tokenId,
        address positionOwner,
        uint256 stopLossPrice,
        uint256 profitTakePrice
    ) external;

    function resetExecutionTime(uint256 tokenId) external;

    function deleteOrder(address account) external;

    function deleteLimitOrder(uint256 tokenId) external;

    function getAnnouncedOrder(address account) external view returns (DelayedOrderStructs.Order memory order);

    function getLimitOrder(uint256 tokenId) external view returns (DelayedOrderStructs.Order memory order);
}
