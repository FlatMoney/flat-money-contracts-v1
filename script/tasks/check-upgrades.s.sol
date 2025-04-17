// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {FileManager} from "../utils/FileManager.sol";
import {FFIHelpers} from "../utils/FFIHelpers.sol";

import "forge-std/StdToml.sol";
import "forge-std/StdStyle.sol";
import "forge-std/console2.sol";
import "forge-std/Vm.sol";

/// @title UpgradesCheckerScript
/// @author dHEDGE
/// @notice Script to check if any module requires an upgrade. Relies on the `forge verify-bytecode` command.
contract UpgradesCheckerScript is FileManager, FFIHelpers {
    using stdToml for string;

    function run() public {
        console2.log("Checking if any module requires upgrade...");

        string memory deploymentsFile = getDeploymentsTomlFile();
        string[] memory moduleNames = vm.parseTomlKeys(deploymentsFile, "$");

        for (uint8 i; i < moduleNames.length; ++i) {
            console2.log("\n");

            address deployedImplementation;
            bool isUpgradeable;

            // Check if the module is an upgradeable one or not and process accordingly.
            if (vm.keyExistsToml(deploymentsFile, string.concat(".", moduleNames[i], ".contract"))) {
                deployedImplementation = deploymentsFile.readAddress(string.concat(".", moduleNames[i], ".contract"));
            } else {
                isUpgradeable = true;
                deployedImplementation = deploymentsFile.readAddress(
                    string.concat(".", moduleNames[i], ".implementation")
                );
            }

            if (_compareImplementationHashes(moduleNames[i], deploymentsFile, isUpgradeable)) {
                console2.log(StdStyle.cyan(string.concat("Module ", moduleNames[i], " does not require an upgrade")));
            } else {
                console2.log(StdStyle.magenta(string.concat("Module ", moduleNames[i], " may require an upgrade")));

                generateDiffFile(
                    moduleNames[i],
                    deploymentsFile.readString(string.concat(".", moduleNames[i], ".commitHash"))
                );

                if (!isUpgradeable) {
                    console2.log(
                        "Module %s is an immutable contract, skipping upgrade safety validation",
                        moduleNames[i]
                    );
                } else {
                    // Check if the upgrade is safe to do by comparing storage layouts.
                    try this.validateUpgrade(moduleNames[i]) {
                        console2.log(StdStyle.green(string.concat("Module ", moduleNames[i], " is safe to upgrade")));
                    } catch {
                        console2.log(StdStyle.red(string.concat("Module ", moduleNames[i], " is not safe to upgrade")));
                    }
                }
            }
        }

        console2.log(StdStyle.green("Upgrades check completed"));
    }

    function validateUpgrade(string memory moduleName_) external {
        string memory oldImplementationQualifiedPath = getFlattenedContractQualifiedPath(moduleName_);
        string memory newImplementationQualifiedPath = getContractQualifiedPath(moduleName_);

        Options memory options;
        options.referenceContract = oldImplementationQualifiedPath;

        Upgrades.validateUpgrade(newImplementationQualifiedPath, options);
    }

    function _compareImplementationHashes(
        string memory moduleName_,
        string memory deploymentsFile,
        bool isUpgradeableModule
    ) private view returns (bool isSame_) {
        bytes32 oldImplementationHash = deploymentsFile
            .readAddress(string.concat(".", moduleName_, (isUpgradeableModule) ? ".implementation" : ".contract"))
            .codehash;

        bytes32 newImplementationHash = keccak256(
            abi.encodePacked(vm.getDeployedCode(getContractQualifiedPath(moduleName_)))
        );

        return newImplementationHash == oldImplementationHash;
    }
}
