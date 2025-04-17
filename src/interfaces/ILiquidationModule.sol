// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

interface ILiquidationModule {
    function liquidationFeeRatio() external view returns (uint128 liquidationFeeRatio);

    function liquidationBufferRatio() external view returns (uint128 liquidationBufferRatio);

    function liquidationFeeUpperBound() external view returns (uint256 feeUpperBound);

    function liquidationFeeLowerBound() external view returns (uint256 feeLowerBound);

    function liquidate(uint256 tokenID, bytes[] calldata priceUpdateData) external payable;

    function liquidate(uint256 tokenID) external;

    function liquidate(
        uint256[] calldata tokenID,
        bytes[] calldata priceUpdateData
    ) external payable returns (uint256[] memory liquidatedIDs);

    function liquidate(uint256[] calldata tokenID) external returns (uint256[] memory liquidatedIDs);

    function canLiquidate(uint256 tokenId) external view returns (bool liquidatable);

    function canLiquidate(uint256 tokenId, uint256 price) external view returns (bool liquidatable);

    function getLiquidationFee(uint256 tokenId) external view returns (uint256 liquidationFee);

    function getLiquidationMargin(uint256 additionalSize) external view returns (uint256 liquidationMargin);

    function getLiquidationMargin(
        uint256 additionalSize,
        uint256 price
    ) external view returns (uint256 liquidationMargin);

    function getLiquidationFee(uint256 positionSize, uint256 price) external view returns (uint256 liquidationFee);
}
