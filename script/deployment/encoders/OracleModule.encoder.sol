// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {OracleModule} from "../../../src/OracleModule.sol";
import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {IChainlinkAggregatorV3} from "../../../src/interfaces/IChainlinkAggregatorV3.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "../../../src/interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

import "forge-std/StdToml.sol";

contract OracleModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getCommonContractsConfigTomlFile();

        return
            abi.encodeCall(
                OracleModule.initialize,
                (
                    configTomlFile.readAddress(".OracleModule.owner"),
                    IPyth(configTomlFile.readAddress(".OracleModule.pythContract"))
                )
            );
    }
}
