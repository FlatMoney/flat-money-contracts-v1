// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {FlatcoinVault} from "../../src/FlatcoinVault.sol";

import {FileManager} from "../utils/FileManager.sol";
import {BatchScript} from "../utils/BatchScript.sol";
import {InitScript} from "../utils/InitScript.sol";
import {DeployCommonContractsScript} from "./deploy-common-contract.s.sol";

import "../../src/interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "../deployment/encoders/Index.sol";

import "forge-std/StdStyle.sol";
import "forge-std/StdToml.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @title UpgradeCommonContract
/// @author dHEDGE
/// @notice Script to upgrade a module via Gnosis Safe multisend txs.
/// @dev OZ Docs are available at https://docs.openzeppelin.com/upgrades-plugins/1.x/api-foundry-upgrades#Upgrades
contract UpgradeCommonContractScript is BatchScript, InitScript, DeployCommonContractsScript {
    using stdToml for string;

    modifier deploymentMode() virtual override(InitScript, DeployCommonContractsScript) {
        string memory deploymentsFile = getCommonContractDeploymentsTomlFile();

        _;

        if (_deploymentsSuccessful && _isBroadcasting) return;

        // Revert file changes in case of incomplete deployments or non-broadcast mode.
        revertFileChanges(getCommonContractsDeploymentsFilePath());

        if (!_deploymentsSuccessful) revert(StdStyle.red("Reverting file changes due to incomplete deployments"));
        else if (!_isBroadcasting) console2.log(StdStyle.yellow("Reverting file changes due to non-broadcast mode"));
    }

    function run(string[] memory contractNames_) public deploymentMode {
        bool useSafeAPI = vm.parseBool(vm.prompt("Use the Safe API for upgrading? (true/false)"));

        if (useSafeAPI) {
            upgradeViaSafe(contractNames_);
        } else {
            try this.prepareUpgrade(contractNames_) {
                _deploymentsSuccessful = true;
            } catch Error(string memory reason) {
                console2.log(StdStyle.red(string.concat("Implementation deployment failed: ", reason)));
            } catch {
                console2.log(StdStyle.red("An error occurred during the upgrade preparation process"));
            }
        }
    }

    /// @dev Function to deploy new implementation contracts and upgrade the proxy via Gnosis Safe multisend txs.
    /// @param contractNames_ The names of the module to be upgraded without ".sol" extension.
    function upgradeViaSafe(string[] memory contractNames_) public {
        try this.upgradeViaSafeExternal(contractNames_) {
            _deploymentsSuccessful = true;
        } catch Error(string memory reason) {
            console2.log(StdStyle.red(string.concat("Upgrade via SAFE failed: ", reason)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the upgrade process"));
        }
    }

    /// @dev Should not be directly called by the script runner.
    function upgradeViaSafeExternal(string[] memory contractNames_) external {
        require(
            msg.sender == address(this),
            "UpgradeCommonContractsScript: upgradeViaSafeExternal can only be called by this contract"
        );

        string memory deploymentsFile = getCommonContractDeploymentsTomlFile();

        console2.log("Upgrading %s modules in a batch\n", contractNames_.length);

        for (uint8 i; i < contractNames_.length; ++i) {
            string memory contractConfigKey = string.concat(".", contractNames_[i]);

            // Check that the contract exists in the deployments file.
            if (!vm.keyExistsToml(deploymentsFile, contractConfigKey)) {
                revert(string.concat("Contract ", contractNames_[i], " not found in deployments file"));
            }

            // If the contract is an immutable contract meaning, it has only `contract` as the value in the deployments file,
            // deploy a new implementation contract and create a transaction to authorize this new implementation.
            if (vm.keyExistsToml(deploymentsFile, string.concat(contractConfigKey, ".contract"))) {
                console2.log("Contract %s is an immutable contract", contractNames_[i]);
                console2.log("Deploying a new implementation contract for %s", contractNames_[i]);

                deployImmutableContract(contractNames_[i]);
            } else {
                string memory configFile = getCommonContractsConfigTomlFile();

                if (vm.keyExistsToml(configFile, string.concat(contractConfigKey, ".proxyType"))) {
                    string memory storedProxyType = configFile.readString(
                        string.concat(contractConfigKey, ".proxyType")
                    );

                    if (!_compareStrings(storedProxyType, "transparent")) {
                        revert("Proxy type not found/supported");
                    }

                    address newImplementation = prepareUpgrade(contractNames_[i]);

                    console2.log("Module %s is a transparent proxy contract", contractNames_[i]);

                    addToBatch(
                        deploymentsFile.readAddress(string.concat(contractConfigKey, ".proxyAdmin")),
                        abi.encodeCall(
                            ProxyAdmin.upgradeAndCall,
                            (
                                ITransparentUpgradeableProxy(
                                    deploymentsFile.readAddress(string.concat(contractConfigKey, ".proxy"))
                                ),
                                newImplementation,
                                bytes("")
                            )
                        )
                    );
                } else {
                    revert("Module type not found");
                }
            }
        }

        // TODO: Fix the batch execution logic due to recent SAFE API changes.
        // executeBatch(
        //     getCommonContractsConfigTomlFile().readAddress(string.concat(contractConfigKey, ".owner")),
        //     _isBroadcasting
        // );

        if (_isBroadcasting) console2.log(StdStyle.green("\nContract upgrade transactions sent to SAFE"));
    }

    /// @dev Used by the `run` function by calling this function via a try-catch block.
    /// @param contractNames_ The names of the module to be upgraded without ".sol" extension.
    function prepareUpgrade(string[] memory contractNames_) external {
        for (uint8 i; i < contractNames_.length; ++i) {
            prepareUpgrade(contractNames_[i]);
        }
    }

    /// @notice Deploys the implementation contract and returns the address.
    /// @dev Note that the new contract must contain `@custom:oz-upgrades-from <reference>` annotation.
    ///      Where reference is the name of the module to upgrade from.
    /// @dev Use this function to validate and deploy the new implementation contract.
    ///      This function can be used to build a Gnosis Safe transaction using Safe Transaction Builder.
    /// @param contractName_ The name of the contract to upgrade to.
    function prepareUpgrade(string memory contractName_) public returns (address newImplementation) {
        string memory referenceContractQualifiedPath = getFlattenedContractQualifiedPath(contractName_);
        string memory upgradeContractQualifiedPath = getContractQualifiedPath(contractName_);

        Options memory options; // Using the default options.

        // Refer the old implementation contract for storage layout comparisons.
        options.referenceContract = referenceContractQualifiedPath;

        vm.startBroadcast();
        newImplementation = Upgrades.prepareUpgrade(upgradeContractQualifiedPath, options);
        vm.stopBroadcast();

        _afterUpgrade(contractName_, newImplementation);
    }

    function initialize() internal override(InitScript, DeployCommonContractsScript) {
        DeployCommonContractsScript.initialize();
    }

    function _afterImmutableDeployment(string memory contractName_, address contract_) internal override {
        string memory deploymentsFilePath = getCommonContractsDeploymentsFilePath();

        vm.writeToml(vm.toString(contract_), deploymentsFilePath, string.concat(".", contractName_, ".contract"));

        if (_isBroadcasting) {
            flattenContract(contractName_);
            uploadSelectors(contractName_);
        }

        (bool success, ) = (contract_).call(abi.encodeWithSignature("MODULE_KEY()"));

        if (success) {
            console2.log(
                StdStyle.yellow(
                    string.concat(
                        "Contract ",
                        contractName_,
                        " has a MODULE_KEY() function. Please authorize this module manually"
                    )
                )
            );

            return;
        }

        // Update entries in the deployments file.
        vm.writeToml(vm.toString(contract_), deploymentsFilePath, string.concat(".", contractName_, ".contract"));
        vm.writeToml(
            vm.toString(getCommitHash()),
            deploymentsFilePath,
            string.concat(".", contractName_, ".commitHash")
        );
    }

    function _afterUpgrade(string memory contractName_, address newImplementation_) private {
        string memory proxyKey = string.concat(".", contractName_, ".proxy");
        string memory deploymentsFilePath = getCommonContractsDeploymentsFilePath();
        string memory deploymentsFile = getCommonContractDeploymentsTomlFile();

        // If the deployments file exists as well as the original contract configs, update the implementation address.
        if (vm.keyExistsToml(deploymentsFile, proxyKey)) {
            ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(deploymentsFile.readAddress(proxyKey));

            // Update the implementation address in the deployments file.
            vm.writeToml(
                vm.toString(newImplementation_),
                deploymentsFilePath,
                string.concat(".", contractName_, ".implementation")
            );
            // Update the commit hash in the deployments file.
            vm.writeToml(
                vm.toString(getCommitHash()),
                deploymentsFilePath,
                string.concat(".", contractName_, ".commitHash")
            );

            console2.log("\nUse the following data for creating a transaction: ");
            console2.log(
                "Proxy admin address: %s",
                deploymentsFile.readAddress(string.concat(".", contractName_, ".proxyAdmin"))
            );
            console2.logBytes(abi.encodeCall(ProxyAdmin.upgradeAndCall, (proxy, newImplementation_, bytes(""))));
        } else {
            console2.log("Key %s not found", contractName_);
            console2.log("Skipping updating the implementation address for %s", contractName_);
        }

        console2.log("New implementation for %s deployed at: %s", contractName_, newImplementation_);

        if (_isBroadcasting) {
            flattenContract(contractName_);
            uploadSelectors(contractName_);
        }
    }
}
