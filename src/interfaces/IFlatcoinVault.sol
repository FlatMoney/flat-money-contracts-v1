// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import "./structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "./structs/LeverageModuleStructs.sol" as LeverageModuleStructs;

interface IFlatcoinVault {
    function collateral() external view returns (IERC20Metadata collateral);

    function stableCollateralTotal() external view returns (uint256 totalAmount);

    function stableCollateralCap() external view returns (uint256 collateralCap);

    function skewFractionMax() external view returns (uint256 skewFractionMax);

    function maxDeltaError() external view returns (uint256 maxDeltaError);

    function maxPositions() external view returns (uint256 maxPositions);

    function moduleAddress(bytes32 moduleKey) external view returns (address moduleAddress);

    function isAuthorizedModule(address module) external view returns (bool status);

    function isModulePaused(bytes32 moduleKey) external view returns (bool paused);

    function sendCollateral(address to, uint256 amount) external;

    function setPosition(LeverageModuleStructs.Position memory position, uint256 tokenId) external;

    function deletePosition(uint256 tokenId) external;

    function updateStableCollateralTotal(int256 stableCollateralAdjustment) external;

    function updateGlobalMargin(int256 marginDelta) external;

    function updateGlobalPositionData(uint256 price, int256 marginDelta, int256 additionalSizeDelta) external;

    function isPositionOpenWhitelisted(address account) external view returns (bool whitelisted);

    function isMaxPositionsReached() external view returns (bool maxPositionsReached);

    function getMaxPositionIds() external view returns (uint256[] memory openPositionIds);

    function getPosition(uint256 tokenId) external view returns (LeverageModuleStructs.Position memory position);

    function getGlobalPositions() external view returns (FlatcoinVaultStructs.GlobalPositions memory globalPositions);

    function checkSkewMax(uint256 sizeChange, int256 stableCollateralChange) external view;

    function checkCollateralCap(uint256 depositAmount) external view;

    function checkGlobalMarginPositive() external view;
}
