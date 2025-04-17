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
import {DeployModulesScript} from "./deploy-module.s.sol";

import "../../src/interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "../deployment/encoders/Index.sol";

import "forge-std/StdStyle.sol";
import "forge-std/StdToml.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @title UpgradeModule
/// @author dHEDGE
/// @notice Script to upgrade a module via Gnosis Safe multisend txs.
/// @dev OZ Docs are available at https://docs.openzeppelin.com/upgrades-plugins/1.x/api-foundry-upgrades#Upgrades
contract UpgradeModuleScript is BatchScript, InitScript, DeployModulesScript {
    using stdToml for string;

    /// @dev Function to deploy new implementation contracts and upgrade the proxy via Gnosis Safe multisend txs.
    /// @param moduleNames_ The names of the module to be upgraded without ".sol" extension.
    function upgradeViaSafe(string[] memory moduleNames_) public deploymentMode {
        try this.upgradeViaSafeExternal(moduleNames_) {
            _deploymentsSuccessful = true;
        } catch Error(string memory reason) {
            console2.log(StdStyle.red(string.concat("Upgrade via SAFE failed: ", reason)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the upgrade process"));
        }
    }

    /// @dev Should not be directly called by the script runner.
    function upgradeViaSafeExternal(string[] memory moduleNames_) external {
        require(
            msg.sender == address(this),
            "UpgradeModule: upgradeViaSafeExternal can only be called by this contract"
        );

        string memory deploymentsFile = getDeploymentsTomlFile();

        console2.log("Upgrading %s modules in a batch\n", moduleNames_.length);

        for (uint8 i; i < moduleNames_.length; ++i) {
            // If the module is an immutable contract meaning, it has only `contract` as the value in the deployments file,
            // deploy a new implementation contract and create a transaction to authorize this new implementation.
            if (vm.keyExistsToml(deploymentsFile, string.concat(".", moduleNames_[i], ".contract"))) {
                console2.log("Module %s is an immutable contract", moduleNames_[i]);
                console2.log("Deploying a new implementation contract for %s", moduleNames_[i]);

                deployImmutableContract(moduleNames_[i]);
            } else {
                string memory configFile = getConfigTomlFile();

                ProxyType proxyType;

                if (vm.keyExistsToml(configFile, string.concat(".", moduleNames_[i], ".proxyType"))) {
                    string memory storedProxyType = configFile.readString(
                        string.concat(".", moduleNames_[i], ".proxyType")
                    );

                    if (_compareStrings(storedProxyType, "beacon")) {
                        proxyType = ProxyType.beacon;
                    } else if (_compareStrings(storedProxyType, "transparent")) {
                        proxyType = ProxyType.transparent;
                    } else {
                        revert("Proxy type not found");
                    }

                    address newImplementation = prepareUpgrade(moduleNames_[i], proxyType);

                    // Then create a transaction to upgrade the proxy according to the `proxyType`.
                    if (proxyType == ProxyType.beacon) {
                        console2.log("Module %s is a beacon proxy contract", moduleNames_[i]);
                        proxyType = ProxyType.beacon;

                        addToBatch(
                            getBeaconsTomlFile().readAddress(string.concat(".", moduleNames_[i], ".beacon")),
                            abi.encodeCall(UpgradeableBeacon.upgradeTo, (newImplementation))
                        );
                    } else {
                        console2.log("Module %s is a transparent proxy contract", moduleNames_[i]);
                        proxyType = ProxyType.transparent;

                        addToBatch(
                            deploymentsFile.readAddress(string.concat(".", moduleNames_[i], ".proxyAdmin")),
                            abi.encodeCall(
                                ProxyAdmin.upgradeAndCall,
                                (
                                    ITransparentUpgradeableProxy(
                                        deploymentsFile.readAddress(string.concat(".", moduleNames_[i], ".proxy"))
                                    ),
                                    newImplementation,
                                    bytes("")
                                )
                            )
                        );
                    }
                } else {
                    revert("Module type not found");
                }
            }
        }

        if (encodedTxns.length != 0) {
            executeBatch(getConfigTomlFile().readAddress(".owner"), _isBroadcasting);

            if (_isBroadcasting) console2.log(StdStyle.green("\nModule upgrade transactions sent to SAFE"));
        }
    }

    /// @notice Deploys the implementation contract and returns the address.
    /// @dev Note that the new module must contain `@custom:oz-upgrades-from <reference>` annotation.
    ///      Where reference is the name of the module to upgrade from.
    /// @dev Use this function to validate and deploy the new implementation contract.
    ///      This function can be used to build a Gnosis Safe transaction using Safe Transaction Builder.
    /// @param moduleName_ The name of the module/contract to upgrade to.
    function prepareUpgrade(
        string memory moduleName_,
        ProxyType proxyType_
    ) public returns (address newImplementation) {
        string memory referenceContractQualifiedPath = getFlattenedContractQualifiedPath(moduleName_);
        string memory upgradeContractQualifiedPath = getContractQualifiedPath(moduleName_);

        Options memory options; // Using the default options.

        // Refer the old implementation contract for storage layout comparisons.
        options.referenceContract = referenceContractQualifiedPath;

        vm.startBroadcast();
        newImplementation = Upgrades.prepareUpgrade(upgradeContractQualifiedPath, options);
        vm.stopBroadcast();

        _afterUpgrade(moduleName_, newImplementation, proxyType_);
    }

    function _afterImmutableDeployment(string memory moduleName_, address contract_) internal override {
        string memory deploymentsFilePath = getModuleDeploymentsFilePath();

        vm.writeToml(vm.toString(contract_), deploymentsFilePath, string.concat(".", moduleName_, ".contract"));
        vm.writeToml(vm.toString(getCommitHash()), deploymentsFilePath, string.concat(".", moduleName_, ".commitHash"));

        if (_isBroadcasting) {
            flattenContract(moduleName_);
            uploadSelectors(moduleName_);
        }

        (bool success, bytes memory data) = (contract_).call(abi.encodeWithSignature("MODULE_KEY()"));

        if (!success) {
            console2.log(
                StdStyle.yellow(
                    string.concat(
                        "Module ",
                        moduleName_,
                        " does not have a MODULE_KEY() function. Please authorize this module manually"
                    )
                )
            );

            console2.log("Skipping authorization of the new implementation for %s", moduleName_);

            return;
        } else {
            console2.log("Authorizing the new implementation for %s", moduleName_);

            addToBatch(
                getDeploymentsTomlFile().readAddress(".FlatcoinVault.proxy"),
                abi.encodeCall(
                    FlatcoinVault.addAuthorizedModule,
                    (
                        FlatcoinVaultStructs.AuthorizedModule({
                            moduleAddress: contract_,
                            moduleKey: abi.decode(data, (bytes32))
                        })
                    )
                )
            );
        }
    }

    function _afterUpgrade(string memory moduleName_, address newImplementation_, ProxyType proxyType_) private {
        string memory proxyKey = string.concat(".", moduleName_, ".proxy");
        string memory deploymentsFilePath = getModuleDeploymentsFilePath();
        string memory deploymentsFile = getDeploymentsTomlFile();

        // If the deployments file exists as well as the original module configs, update the implementation address.
        if (vm.keyExistsToml(deploymentsFile, proxyKey)) {
            ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(deploymentsFile.readAddress(proxyKey));

            // If the module is a beacon proxy, update the implementation address in the beacons file.
            if (proxyType_ == ProxyType.beacon) {
                string memory beaconsFilePath = getBeaconsFilePath();

                vm.writeToml(
                    vm.toString(newImplementation_),
                    beaconsFilePath,
                    string.concat(".", moduleName_, ".implementation")
                );
                vm.writeToml(
                    vm.toString(getCommitHash()),
                    beaconsFilePath,
                    string.concat(".", moduleName_, ".commitHash")
                );

                console2.log("\nUse the following data for creating a transaction: ");
                console2.log(
                    "Beacon address: %s",
                    getBeaconsTomlFile().readAddress(string.concat(".", moduleName_, ".beacon"))
                );
                console2.log("Hex data: ");
                console2.logBytes(abi.encodeCall(UpgradeableBeacon.upgradeTo, (newImplementation_)));
            } else {
                // The only other proxy type is the transparent proxy.
                // Update the implementation address in the deployments file.
                vm.writeToml(
                    vm.toString(newImplementation_),
                    deploymentsFilePath,
                    string.concat(".", moduleName_, ".implementation")
                );
                vm.writeToml(
                    vm.toString(getCommitHash()),
                    deploymentsFilePath,
                    string.concat(".", moduleName_, ".commitHash")
                );

                console2.log("\nUse the following data for creating a transaction: ");
                console2.log(
                    "Proxy admin address: %s",
                    deploymentsFile.readAddress(string.concat(".", moduleName_, ".proxyAdmin"))
                );
                console2.logBytes(abi.encodeCall(ProxyAdmin.upgradeAndCall, (proxy, newImplementation_, bytes(""))));
            }
        } else {
            console2.log("Key %s not found", moduleName_);
            console2.log("Skipping updating the implementation address for %s", moduleName_);
        }

        console2.log("New implementation for %s deployed at: %s", moduleName_, newImplementation_);

        if (_isBroadcasting) {
            flattenContract(moduleName_);
            uploadSelectors(moduleName_);
        }
    }
}
