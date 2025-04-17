// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

import {FlatcoinVault} from "../../src/FlatcoinVault.sol";

import {FileManager} from "../utils/FileManager.sol";
import {BatchScript} from "../utils/BatchScript.sol";
import {FFIHelpers} from "../utils/FFIHelpers.sol";
import {InitScript} from "../utils/InitScript.sol";
import "../deployment/encoders/Index.sol";

import "forge-std/StdStyle.sol";
import "forge-std/StdToml.sol";
import "forge-std/console2.sol";

/// @title PauseUnpauseScript
/// @author dHEDGE
/// @notice Script to pause or unpause multiple modules via Gnosis Safe multisend txs.
contract PauseUnpauseScript is BatchScript, FileManager, InitScript, FFIHelpers {
    using stdToml for string;

    /// @dev Function to pause a module via Gnosis Safe.
    /// @param moduleNames_ The module name to be paused without ".sol" extension.
    function pauseViaSafe(string[] memory moduleNames_) public {
        console2.log("Pausing %s modules in a batch\n", moduleNames_.length);

        string memory deploymentsFile = getDeploymentsTomlFile();
        FlatcoinVault vault = FlatcoinVault(getDeploymentsTomlFile().readAddress(".FlatcoinVault.proxy"));

        for (uint8 i; i < moduleNames_.length; ++i) {
            address module = deploymentsFile.readAddress(string.concat(".", moduleNames_[i], ".proxy"));

            // Call the MODULE_KEY() function to get the module key.
            // If it doesn't exist then either the module is immutable and/or not an authorized module.
            (bool success, bytes memory data) = (module).call(abi.encodeWithSignature("MODULE_KEY()"));

            if (!success) {
                console2.log(
                    StdStyle.yellow(
                        string.concat(
                            "Module ",
                            moduleNames_[i],
                            " doesn't contain a MODULE_KEY() function. Skipping pause..."
                        )
                    )
                );
                continue;
            }

            bytes32 moduleKey = abi.decode(data, (bytes32));

            addToBatch(address(vault), abi.encodeCall(FlatcoinVault.pauseModule, moduleKey));

            console2.log("Module %s added to batch", moduleNames_[i]);
        }

        console2.log("\n");

        executeBatch(getConfigTomlFile().readAddress(".owner"), _isBroadcasting);

        console2.log(StdStyle.green("\nModule pause transactions sent to SAFE"));
    }

    /// @dev Function to unpause a module via Gnosis Safe.
    /// @param moduleNames_ The module name to be paused without ".sol" extension.
    function unpauseViaSafe(string[] memory moduleNames_) public {
        console2.log("Unpausing %s modules in a batch\n", moduleNames_.length);

        string memory deploymentsFile = getDeploymentsTomlFile();
        FlatcoinVault vault = FlatcoinVault(getDeploymentsTomlFile().readAddress(".FlatcoinVault.proxy"));

        for (uint8 i; i < moduleNames_.length; ++i) {
            address module = deploymentsFile.readAddress(string.concat(".", moduleNames_[i], ".proxy"));

            // Call the MODULE_KEY() function to get the module key.
            // If it doesn't exist then either the module is immutable and/or not an authorized module.
            (bool success, bytes memory data) = (module).call(abi.encodeWithSignature("MODULE_KEY()"));

            if (!success) {
                console2.log(
                    StdStyle.yellow(
                        string.concat(
                            "Module ",
                            moduleNames_[i],
                            " doesn't contain a MODULE_KEY() function. Skipping unpause..."
                        )
                    )
                );
                continue;
            }

            bytes32 moduleKey = abi.decode(data, (bytes32));

            addToBatch(address(vault), abi.encodeCall(FlatcoinVault.unpauseModule, moduleKey));

            console2.log("Module %s added to batch", moduleNames_[i]);
        }

        console2.log("\n");

        executeBatch(getConfigTomlFile().readAddress(".owner"), _isBroadcasting);

        console2.log(StdStyle.green("\nModule unpause transactions sent to SAFE"));
    }
}
