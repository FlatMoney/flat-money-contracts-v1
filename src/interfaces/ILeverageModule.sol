// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "./structs/DelayedOrderStructs.sol" as DelayedOrderStructs;
import "./structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

interface ILeverageModule is IERC721Enumerable {
    function tokenIdNext() external view returns (uint256 tokenId);

    function marginMin() external view returns (uint256 marginMin);

    function leverageMin() external view returns (uint256 leverageMin);

    function leverageMax() external view returns (uint256 leverageMax);

    function executeOpen(address account, DelayedOrderStructs.Order calldata order) external returns (uint256 tokenId);

    function executeAdjust(DelayedOrderStructs.Order calldata order) external;

    function executeClose(DelayedOrderStructs.Order calldata order) external returns (uint256 marginAfterPositionClose);

    function mint(address to) external returns (uint256 tokenId);

    function burn(uint256 tokenId) external;

    function getPositionSummary(
        uint256 tokenId
    ) external view returns (LeverageModuleStructs.PositionSummary memory positionSummary);

    function getPositionSummary(
        LeverageModuleStructs.Position memory position,
        uint256 price
    ) external view returns (LeverageModuleStructs.PositionSummary memory positionSummary);

    function checkLeverageCriteria(uint256 margin, uint256 size) external view;
}
