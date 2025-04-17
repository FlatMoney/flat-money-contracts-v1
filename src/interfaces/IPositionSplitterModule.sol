// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

interface IPositionSplitterModule {
    function split(
        uint256 tokenId_,
        uint64 positionFraction_,
        address owner_
    ) external returns (uint256 newPositionId_);
}
