// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {GlobalStorage} from "./GlobalStorage.sol";

import "forge-std/Vm.sol";
import "forge-std/Script.sol";

abstract contract FileManager is GlobalStorage {
    struct ExistingFiles {
        string filePath;
        string fileContents;
    }

    mapping(string filePath => bool newlyCreated) private _newlyCreatedFiles;
    mapping(string filePath => ExistingFiles) private _existingFiles;

    function getConfigTomlFile() internal returns (string memory configTomlFile) {
        string memory configFilePath = getModulesConfigFilePath();

        require(vm.isFile(configFilePath), string.concat("Config file not found: ", configFilePath));

        configTomlFile = vm.readFile(configFilePath);

        vm.closeFile(configFilePath);
    }

    function getCommonContractsConfigTomlFile() internal returns (string memory commonContractsConfigTomlFile) {
        string memory commonContractsConfigFilePath = getCommonContractConfigFilePath();

        require(
            vm.isFile(commonContractsConfigFilePath),
            string.concat("Common contracts config file not found: ", commonContractsConfigFilePath)
        );

        commonContractsConfigTomlFile = vm.readFile(commonContractsConfigFilePath);

        vm.closeFile(commonContractsConfigFilePath);
    }

    function getDeploymentsTomlFile() internal returns (string memory deploymentsTomlFile) {
        string memory deploymentsFilePath = getModuleDeploymentsFilePath();

        require(vm.isFile(deploymentsFilePath), string.concat("Deployments file not found: ", deploymentsFilePath));

        deploymentsTomlFile = vm.readFile(deploymentsFilePath);

        vm.closeFile(deploymentsFilePath);
    }

    function getCommonContractDeploymentsTomlFile() internal returns (string memory commonContractsTomlFile) {
        string memory commonContractsFilePath = getCommonContractsDeploymentsFilePath();

        require(
            vm.isFile(commonContractsFilePath),
            string.concat("Common contracts deployments file not found: ", commonContractsFilePath)
        );

        commonContractsTomlFile = vm.readFile(commonContractsFilePath);

        vm.closeFile(commonContractsFilePath);
    }

    function getBeaconsTomlFile() internal returns (string memory beaconsTomlFile) {
        string memory beaconsFilePath = getBeaconsFilePath();

        require(vm.isFile(beaconsFilePath), string.concat("Beacons file not found: ", beaconsFilePath));

        beaconsTomlFile = vm.readFile(beaconsFilePath);

        vm.closeFile(beaconsFilePath);
    }

    function getOracleDataTomlFile() internal returns (string memory oracleDataTomlFile) {
        string memory oracleDataFilePath = getOracleDataFilePath();

        require(vm.isFile(oracleDataFilePath), string.concat("Oracle data file not found: ", oracleDataFilePath));

        oracleDataTomlFile = vm.readFile(oracleDataFilePath);

        vm.closeFile(oracleDataFilePath);
    }

    function getModulesConfigFilePath() internal view returns (string memory configFilePath_) {
        return string.concat(getConfigFileDir(), getTag(), ".toml");
    }

    function getCommonContractConfigFilePath() internal view returns (string memory commonContractsConfigFilePath_) {
        return string.concat(getConfigFileDir(), "CommonContracts.toml");
    }

    function getBeaconsFilePath() internal view returns (string memory beaconsFilePath_) {
        return string.concat(getDeploymentsDirPath(), "Beacons.toml");
    }

    function getOracleDataFilePath() internal view returns (string memory oracleDataFilePath_) {
        return string.concat(getDeploymentsDirPath(), "OracleData.toml");
    }

    function getModuleDeploymentsFilePath() internal view returns (string memory deploymentsFilePath_) {
        return string.concat(getDeploymentsDirPath(), getTag(), ".toml");
    }

    function getCommonContractsDeploymentsFilePath() internal view returns (string memory commonContractsFilePath_) {
        return string.concat(getDeploymentsDirPath(), "CommonContracts.toml");
    }

    function getConfigFileDir() internal view returns (string memory configFileDir_) {
        return string.concat(vm.projectRoot(), "/script/deployment/configs/", vm.toString(block.chainid), "/");
    }

    function getDeploymentsDirPath() internal view returns (string memory deploymentsDirPath_) {
        return string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), "/");
    }

    function getFlattenedContractQualifiedPath(
        string memory moduleName_
    ) internal view returns (string memory flattenedContractPath_) {
        return string.concat(moduleName_, ".", vm.toString(block.chainid), ".flattened.sol:", moduleName_);
    }

    function getFlattenedContractsRelativeDirPath() internal view returns (string memory flattenedContractsDirPath_) {
        return string.concat("src/flattened-contracts/", vm.toString(block.chainid), "/");
    }

    function getContractQualifiedPath(
        string memory moduleName_
    ) internal pure returns (string memory upgradeContractPath_) {
        return string.concat(moduleName_, ".sol:", moduleName_);
    }

    function getTag() internal view returns (string memory tag_) {
        (bool success, bytes memory value) = _globalStorage.staticcall(abi.encodeWithSignature("tag()"));

        require(success, "FileManager: Failed to get tag from global storage");

        return abi.decode(value, (string));
    }

    function createOrSaveFile(string memory filePath_, string memory newFileContents_) internal {
        if (!vm.isFile(filePath_)) {
            vm.writeFile(filePath_, newFileContents_);
            _newlyCreatedFiles[filePath_] = true;
        } else {
            _existingFiles[filePath_] = ExistingFiles(filePath_, vm.readFile(filePath_));
        }
    }

    function revertFileChanges(string memory filePath_) internal {
        if (_newlyCreatedFiles[filePath_]) {
            vm.removeFile(filePath_);
        } else {
            vm.writeFile(filePath_, _existingFiles[filePath_].fileContents);
        }
    }
}
