// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IChainlinkAggregatorV3} from "../../../src/interfaces/IChainlinkAggregatorV3.sol";
import {IOracleModule} from "../../../src/interfaces/IOracleModule.sol";
import {ArbKeeperFee} from "../../../src/misc/ArbKeeperFee.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

/// @dev Although both KeeperFee and ArbKeeperFee constructors are same,
///      we need to have separate encoders for them as they are different contracts.
contract ArbKeeperFeeEncoder is EncoderBase {
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
            configTomlFile_.readAddress(".Modules.ArbKeeperFee.assetToPayWith"),
            configTomlFile_.readAddress(".Modules.ArbKeeperFee.ethOracle"),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.gasUnitsL1"),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.gasUnitsL2"),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.keeperFeeLowerBound"),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.keeperFeeUpperBound"),
            IOracleModule(getCommonContractDeploymentsTomlFile().readAddress(".OracleModule.proxy")),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.profitMarginPercent"),
            configTomlFile_.readUint(".Modules.ArbKeeperFee.stalenessPeriod")
        );

        return keeperFeeOnlyData;
    }
}
