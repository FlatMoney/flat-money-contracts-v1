// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FileManager} from "./FileManager.sol";
import {GlobalStorage} from "./GlobalStorage.sol";

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

abstract contract InitScript is Script, FileManager {
    /// @dev Set to `true` if a script is run in broadcast mode.
    bool internal _isBroadcasting;

    /// @dev Set to `true` if all deployments are successful.
    bool internal _deploymentsSuccessful;

    constructor() {
        initialize();
    }

    function initialize() internal virtual {
        setTag();

        string memory deploymentsConfigDirPath = getDeploymentsDirPath();

        // Ask the script runner if they want to create a new market if one does not exist.
        // If not, then the script will be aborted.
        if (!vm.isDir(deploymentsConfigDirPath)) {
            bool createMarket = vm.parseBool(vm.prompt("Market not found. Create a new market? (true/false)"));

            // If the script runner wants to create a new market then create a new directory for the market.
            if (createMarket) {
                vm.createDir(deploymentsConfigDirPath, false);
            } else {
                revert("Script aborted");
            }
        }

        // Create necessary files if they do not exist.
        {
            createOrSaveFile(getModuleDeploymentsFilePath(), "");
            createOrSaveFile(getBeaconsFilePath(), "");
        }

        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) _isBroadcasting = true;
    }

    // Note that this modifier assumes that a directory exists for the deployments file.
    // - Read the current deployments file contents.
    // - Proceed with the execution of `DeployScript` contract functions.
    // - If `_deploymentsSuccessful` is `true` and `_isBroadcasting` also `true` then:
    //   - Do nothing and return.
    // - Otherwise revert the changes in the current deployments file.
    modifier deploymentMode() virtual {
        string memory deploymentsFile = getDeploymentsTomlFile();
        string memory beaconsFile = getBeaconsTomlFile();

        _;

        if (_deploymentsSuccessful && _isBroadcasting) return;

        // Revert file changes in case of incomplete deployments or non-broadcast mode.
        {
            revertFileChanges(getModuleDeploymentsFilePath());
            revertFileChanges(getBeaconsFilePath());
        }

        if (!_deploymentsSuccessful) revert(StdStyle.red("Reverting file changes due to incomplete deployments"));
        else if (!_isBroadcasting) console2.log(StdStyle.yellow("Reverting file changes due to non-broadcast mode"));
    }

    // Tag to identify a specific market.
    // For example, there can be two markets on the same chain but different collateral/market assets.
    // A tag is a simple way to identify a specific market for which scripts are being run.
    function setTag() internal virtual {
        string memory tagString = vm.prompt("Enter the market id");
        setStorage("tag()", abi.encode(tagString));
    }
}
