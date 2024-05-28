// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {FlatcoinStructs} from "../libraries/FlatcoinStructs.sol";

interface ILeverageModule is IERC721Enumerable {
    function executeOpen(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function executeAdjust(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function executeClose(address account, address keeper, FlatcoinStructs.Order calldata order) external;

    function burn(uint256 tokenId, bytes32 moduleKey) external;

    function lock(uint256 tokenId, bytes32 moduleKey) external;

    function unlock(uint256 tokenId, bytes32 moduleKey) external;

    function isLocked(uint256 tokenId) external view returns (bool lockStatus);

    function isLockedByModule(uint256 _tokenId, bytes32 _moduleKey) external view returns (bool _lockedByModuleStatus);

    function getPositionSummary(
        uint256 tokenId
    ) external view returns (FlatcoinStructs.PositionSummary memory positionSummary);

    function fundingAdjustedLongPnLTotal() external view returns (int256 _fundingAdjustedPnL);

    function fundingAdjustedLongPnLTotal(
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (int256 _fundingAdjustedPnL);

    function tokenIdNext() external view returns (uint256 tokenId);

    function leverageTradingFee() external view returns (uint256 leverageTradingFee);

    function checkLeverageCriteria(uint256 margin, uint256 size) external view;

    function marginMin() external view returns (uint256 marginMin);

    function getTradeFee(uint256 size) external view returns (uint256 tradeFee);
}
