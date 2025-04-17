// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IChainlinkAggregatorV3} from "../../../src/interfaces/IChainlinkAggregatorV3.sol";
import {IOracleModule} from "../../../src/interfaces/IOracleModule.sol";
import {KeeperFeeBase} from "../../../src/abstracts/KeeperFeeBase.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract OPKeeperFeeEncoder is EncoderBase {
    using stdToml for string;

    struct KeeperFeeOnlyConfigData {
        address assetToPayWith;
        address ethOracle;
        uint256 gasUnitsL1;
        uint256 gasUnitsL2;
        uint256 keeperFeeLowerBound;
        uint256 keeperFeeUpperBound;
        IOracleModule oracleModule;
        uint256 profitMarginPercent;
        uint256 stalenessPeriod;
    }

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getConfigTomlFile();
        address owner = configTomlFile.readAddress(".owner");
        KeeperFeeOnlyConfigData memory keeperFeeOnlyData = _getKeeperFeeOnlyConfigData(configTomlFile);

        return
            abi.encode(
                owner,
                keeperFeeOnlyData.ethOracle,
                keeperFeeOnlyData.oracleModule,
                keeperFeeOnlyData.assetToPayWith,
                keeperFeeOnlyData.profitMarginPercent,
                keeperFeeOnlyData.keeperFeeUpperBound,
                keeperFeeOnlyData.keeperFeeLowerBound,
                keeperFeeOnlyData.gasUnitsL1,
                keeperFeeOnlyData.gasUnitsL2,
                keeperFeeOnlyData.stalenessPeriod
            );
    }

    function _getKeeperFeeOnlyConfigData(
        string memory configTomlFile_
    ) private returns (KeeperFeeOnlyConfigData memory) {
        KeeperFeeOnlyConfigData memory keeperFeeOnlyData = KeeperFeeOnlyConfigData(
            configTomlFile_.readAddress(".Modules.OPKeeperFee.assetToPayWith"),
            configTomlFile_.readAddress(".Modules.OPKeeperFee.ethOracle"),
            configTomlFile_.readUint(".Modules.OPKeeperFee.gasUnitsL1"),
            configTomlFile_.readUint(".Modules.OPKeeperFee.gasUnitsL2"),
            configTomlFile_.readUint(".Modules.OPKeeperFee.keeperFeeLowerBound"),
            configTomlFile_.readUint(".Modules.OPKeeperFee.keeperFeeUpperBound"),
            IOracleModule(getCommonContractDeploymentsTomlFile().readAddress(".OracleModule.proxy")),
            configTomlFile_.readUint(".Modules.OPKeeperFee.profitMarginPercent"),
            configTomlFile_.readUint(".Modules.OPKeeperFee.stalenessPeriod")
        );

        return keeperFeeOnlyData;
    }
}
