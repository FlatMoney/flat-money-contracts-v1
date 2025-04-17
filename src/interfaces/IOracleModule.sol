// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import "./structs/OracleModuleStructs.sol" as OracleModuleStructs;

interface IOracleModule {
    function pythOracleContract() external view returns (IPyth oracleContractAddress);

    function updatePythPrice(address sender, bytes[] calldata priceUpdateData) external payable;

    function getPrice(address asset) external view returns (uint256 price, uint256 timestamp);

    function getPrice(
        address asset,
        uint32 maxAge,
        bool priceDiffCheck
    ) external view returns (uint256 price, uint256 timestamp);

    function getOracleData(address asset) external view returns (OracleModuleStructs.OracleData memory oracleData);

    function setOracles(
        address _asset,
        OracleModuleStructs.OnchainOracle calldata _onchainOracle,
        OracleModuleStructs.OffchainOracle calldata _offchainOracle
    ) external;

    function setMaxDiffPercent(address _asset, uint64 _maxDiffPercent) external;
}
