// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {FileManager} from "./FileManager.sol";

import "forge-std/Vm.sol";
import "forge-std/Script.sol";
import "forge-std/console2.sol";

abstract contract FFIHelpers is Script, FileManager {
    function flattenContract(string memory contractName_) internal {
        string[] memory input = new string[](5);
        input[0] = "forge";
        input[1] = "flatten";
        input[2] = "--output";
        input[3] = string.concat(
            getFlattenedContractsRelativeDirPath(),
            contractName_,
            ".",
            vm.toString(block.chainid),
            ".flattened.sol"
        );
        input[4] = getContractPath(contractName_);

        Vm.FfiResult memory result = vm.tryFfi(input);

        if (result.exitCode != 0) {
            console2.log("Failed to flatten contract %s", contractName_);
            console2.log("Error: ");
            console2.logBytes(result.stderr);
            console2.log("Error string: ", vm.toString(result.stderr));
        }
    }

    function uploadSelectors(string memory contractName_) internal {
        string[] memory input = new string[](4);

        input[0] = "forge";
        input[1] = "selectors";
        input[2] = "upload";
        input[3] = string.concat(getContractPath(contractName_), ":", contractName_);

        Vm.FfiResult memory result = vm.tryFfi(input);

        if (result.exitCode != 0) {
            console2.log("Failed to upload selectors for contract %s", contractName_);
            console2.log("Error: ");
            console2.logBytes(result.stderr);
            console2.log("Error string: ", vm.toString(result.stderr));
        }
    }

    function generateDiffFile(string memory contractName_, string memory latestStoredCommitHash_) internal {
        string[] memory inputs = new string[](3);

        string memory hashWithoutLeading0x = vm.split(latestStoredCommitHash_, "0x")[1];

        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            "git diff ",
            hashWithoutLeading0x,
            " -- ",
            getContractPath(contractName_),
            " | code -"
        );

        console2.log("Generating diff for contract %s", contractName_);

        Vm.FfiResult memory result = vm.tryFfi(inputs);

        if (result.exitCode != 0) {
            console2.log("Error: ", vm.toString(result.stderr));

            console2.log(StdStyle.red(string.concat("Failed to generate diff file for ", contractName_)));
        } else {
            console2.log(StdStyle.green("Diff file generated successfully"));
        }
    }

    function getCommitHash() internal returns (bytes memory gitCommitHash_) {
        string[] memory input = new string[](3);

        input[0] = "git";
        input[1] = "rev-parse";
        input[2] = "HEAD";

        Vm.FfiResult memory result = vm.tryFfi(input);

        if (result.exitCode != 0) {
            console2.log("Error: ", vm.toString(result.stderr));

            revert("Failed to get git commit hash");
        }

        gitCommitHash_ = result.stdout;
    }

    function getContractPath(string memory contractName_) internal returns (string memory filePath_) {
        string[] memory input = new string[](3);

        input[0] = "bash";
        input[1] = "-c";
        input[2] = string.concat("find src -name ", _getContractNameWithExtension(contractName_));

        Vm.FfiResult memory result = vm.tryFfi(input);

        if (result.exitCode != 0) {
            console2.log("Error: ", vm.toString(result.stderr));

            revert(string.concat("Failed to get contract path for ", contractName_));
        }

        filePath_ = string(result.stdout);
    }

    function _getContractNameWithExtension(
        string memory contractNameWithoutExtension_
    ) private pure returns (string memory contractNameWithExtension_) {
        return string.concat(contractNameWithoutExtension_, ".sol");
    }
}
