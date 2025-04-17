// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {FileManager} from "../utils/FileManager.sol";
import {FFIHelpers} from "../utils/FFIHelpers.sol";
import {BatchScript} from "../utils/BatchScript.sol";

import {IChainlinkAggregatorV3} from "src/interfaces/IChainlinkAggregatorV3.sol";
import {IFlatcoinVault} from "../../src/interfaces/IFlatcoinVault.sol";
import {IOracleModule} from "../../src/interfaces/IOracleModule.sol";

import "../../src/interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

import "forge-std/StdStyle.sol";
import "forge-std/StdToml.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

contract AddOracleDataScript is FileManager, BatchScript, FFIHelpers {
    using stdToml for string;

    bool isBroadcasting;

    constructor() {
        isBroadcasting = vm.isContext(VmSafe.ForgeContext.ScriptBroadcast);

        // Create a oracle data file if one doesn't already exist.
        createOrSaveFile(getOracleDataFilePath(), "");
    }

    function run() external {
        try this.addOracle() {
            console2.log(StdStyle.green("AddOracleDataScript: Successfully added oracle data(s)"));
        } catch {
            revertFileChanges(getOracleDataFilePath());

            revert("AddOracleDataScript: Failed to add oracle data(s)");
        }

        if (!isBroadcasting) revertFileChanges(getOracleDataFilePath());
    }

    function addOracle() external {
        require(msg.sender == address(this), "AddOracleDataScript: Caller is not this contract");

        while (true) {
            string memory marketTag = vm.prompt("Market Tag (name of the config file)");
            setStorage("tag()", abi.encode(marketTag));

            string memory configFile = getConfigTomlFile();
            string memory existingOracleData = getOracleDataTomlFile();
            string memory assetName = configFile.readString(".OracleData.name");

            if (vm.keyExistsToml(existingOracleData, string.concat(".", assetName))) {
                console2.log("Asset already exists in oracle data file. Skipping...");
            }

            IOracleModule oracleModule = IOracleModule(
                getCommonContractDeploymentsTomlFile().readAddress(".OracleModule.proxy")
            );

            require(address(oracleModule) != address(0), "AddOracleDataScript: OracleModule address null");

            address asset = configFile.readAddress(".OracleData.address");
            uint64 maxDiffPercent = uint64(configFile.readUint(".OracleData.maxDiffPercent"));

            OracleModuleStructs.OnchainOracle memory onchainOracle = OracleModuleStructs.OnchainOracle(
                IChainlinkAggregatorV3(configFile.readAddress(".OracleData.onchainOracle.oracleContract")),
                uint32(configFile.readUint(".OracleData.onchainOracle.maxAge"))
            );
            OracleModuleStructs.OffchainOracle memory offchainOracle = OracleModuleStructs.OffchainOracle(
                configFile.readBytes32(".OracleData.offchainOracle.priceId"),
                uint32(configFile.readUint(".OracleData.offchainOracle.maxAge")),
                uint32(configFile.readUint(".OracleData.offchainOracle.minConfidenceRatio"))
            );

            // Add the oracle data to the oracle data file if the transaction is broadcasted.
            if (isBroadcasting) {
                string memory oracleDataObj = string.concat(
                    'address = "',
                    vm.toString(configFile.readAddress(".OracleData.address")),
                    '"\n',
                    'chainlinkOracleContract = "',
                    vm.toString(address(onchainOracle.oracleContract)),
                    '"\n',
                    'pythPriceId = "',
                    vm.toString(offchainOracle.priceId),
                    '"\n',
                    "chainlinkOracleMaxAge = ",
                    vm.toString(onchainOracle.maxAge),
                    "\n",
                    "pythMaxAge = ",
                    vm.toString(offchainOracle.maxAge),
                    "\n",
                    "pythPriceConfidenceRatio = ",
                    vm.toString(offchainOracle.minConfidenceRatio),
                    "\n",
                    "maxDiffPercent = ",
                    vm.toString(maxDiffPercent),
                    "\n\n"
                );

                vm.writeFile(
                    getOracleDataFilePath(),
                    string.concat(existingOracleData, "[", assetName, "]\n", oracleDataObj)
                );
            }

            addToBatch(
                address(oracleModule),
                abi.encodeCall(IOracleModule.setOracles, (asset, onchainOracle, offchainOracle))
            );
            addToBatch(address(oracleModule), abi.encodeCall(IOracleModule.setMaxDiffPercent, (asset, maxDiffPercent)));

            console2.log(string.concat("Oracle data for ", assetName, " added successfully"));

            bool continueScript = vm.parseBool(vm.prompt("Do you want to add another asset? (true/false)"));
            if (!continueScript) break;
        }

        address oracleModuleOwner = OwnableUpgradeable(
            getCommonContractDeploymentsTomlFile().readAddress(".OracleModule.proxy")
        ).owner();

        // Note that we are assuming the oracle module owner is a Gnosis Safe contract.
        executeBatch(oracleModuleOwner, isBroadcasting);
    }
}
