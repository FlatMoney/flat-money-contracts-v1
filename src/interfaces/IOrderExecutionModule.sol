// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

interface IOrderExecutionModule {
    function maxExecutabilityAge() external view returns (uint64 maxExecutabilityAge);

    function executeOrder(address account, bytes[] memory priceUpdateData) external payable;

    function executeLimitOrder(uint256 tokenId, bytes[] calldata priceUpdateData) external payable;

    function cancelExistingOrder(address account) external;

    function cancelOrderByModule(address account) external;

    function hasOrderExpired(address account) external view returns (bool expired);
}
