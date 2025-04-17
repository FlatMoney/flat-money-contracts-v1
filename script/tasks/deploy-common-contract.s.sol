// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {EncoderBase} from "../deployment/misc/EncoderBase.sol";
import {FileManager} from "../utils/FileManager.sol";
import {BatchScript} from "../utils/BatchScript.sol";
import {FFIHelpers} from "../utils/FFIHelpers.sol";
import {InitScript} from "../utils/InitScript.sol";
import "../deployment/encoders/Index.sol";

import {FlatcoinVault} from "../../src/FlatcoinVault.sol";

import "../../src/interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;

import "forge-std/StdStyle.sol";
import "forge-std/StdToml.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

/// @title DeployCommonContractsScript
/// @author dHEDGE
/// @notice Deployment script for deploying upgradeable and immutable contracts.
/// @dev The script assumes the following:
///      - The encoded initialization data can be retrieved from an encoder contract.
///      - The encoder contract file name should be the same as the module name with the suffix `.encoder.sol`.
///      - The encoder contract name should be the same as the module name with the suffix `Encoder`.
/// @dev The script doesn't authorize a module for a particular FlatcoinVault.
///      The authorization process should be done separately.
contract DeployCommonContractsScript is BatchScript, InitScript, FFIHelpers {
    using stdToml for string;

    // Note that this modifier assumes that a directory exists for the deployments file.
    // - Read the current deployments file contents.
    // - Proceed with the execution of `DeployScript` contract functions.
    // - If `_deploymentsSuccessful` is `true` and `_isBroadcasting` also `true` then:
    //   - Do nothing and return.
    // - Otherwise revert the changes in the current deployments file.
    modifier deploymentMode() virtual override {
        string memory deploymentsFile = getCommonContractDeploymentsTomlFile();

        _;

        if (_deploymentsSuccessful && _isBroadcasting) return;

        // Revert file changes in case of incomplete deployments or non-broadcast mode.
        revertFileChanges(getCommonContractsDeploymentsFilePath());

        if (!_deploymentsSuccessful) revert(StdStyle.red("Reverting file changes due to incomplete deployments"));
        else if (!_isBroadcasting) console2.log(StdStyle.yellow("Reverting file changes due to non-broadcast mode"));
    }

    /// @notice Function to deploy all modules sequentially.
    /// @dev This is the only function that should be called directly by the script runner.
    /// @dev The `deploymentMode` modifier will revert the file changes in case the `_isBroadcasting` is `false`
    ///      or `_deploymentsSuccessful` is `false`.
    /// @param contractNames_ The names of the modules to be deployed without the `.sol` extension.
    function deployCommonContracts(string[] memory contractNames_) public virtual deploymentMode {
        try this.deployCommonContractsExternal(contractNames_) {
            _deploymentsSuccessful = true;
        } catch Error(string memory errorMessage) {
            console2.log(StdStyle.red(string.concat("Deployments failed with error:", errorMessage)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the deployment process"));
        }
    }

    /// @dev Should not be directly called by the script runner.
    function deployCommonContractsExternal(string[] memory contractNames_) external {
        require(msg.sender == address(this), "DeployScript: Only the script runner can call this function");

        string memory configFile = getCommonContractsConfigTomlFile();
        string memory deploymentsFile = getCommonContractDeploymentsTomlFile();

        for (uint8 i; i < contractNames_.length; ++i) {
            string memory moduleName = contractNames_[i];

            // Check if the common contract is already deployed.
            // If it is, then skip the deployment process for the contract.
            if (vm.keyExistsToml(deploymentsFile, string.concat(".", moduleName))) {
                console2.log("Reached here: ", moduleName);
                console2.log(
                    StdStyle.yellow(
                        string.concat(
                            "Module ",
                            moduleName,
                            " is a common contract and deployed at address: ",
                            vm.toString(deploymentsFile.readAddress(string.concat(".", moduleName)))
                        )
                    )
                );

                console2.log(
                    StdStyle.yellow(string.concat(moduleName, " already exists in common contracts. Skipping..."))
                );

                continue;
            }

            // The config of a common contract is stored as the root-key in the common contracts config TOML file.
            string memory configKey = string.concat(".", moduleName);

            if (!configFile.readBool(string.concat(configKey, ".isUpgradeable"))) {
                deployImmutableContract(moduleName);
            } else {
                if (_compareStrings(configFile.readString(string.concat(configKey, ".proxyType")), "transparent")) {
                    deployTransparentUpgradeableContract(moduleName);
                } else {
                    revert("Proxy type not found/supported");
                }
            }
        }

        // If `_isBroadcasting` is true then execute the batch.
        // Otherwise just simulate the execution.
        if (encodedTxns.length != 0) executeBatch(configFile.readAddress(".owner"), _isBroadcasting);
    }

    function initialize() internal virtual override {
        string memory deploymentsDirPath = getDeploymentsDirPath();

        if (!vm.isDir(deploymentsDirPath)) {
            vm.createDir(deploymentsDirPath, false);
        }

        createOrSaveFile(getCommonContractsDeploymentsFilePath(), "");

        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) _isBroadcasting = true;
    }

    /// @dev For deployment of Transparent Proxy upgradeable contracts.
    function deployTransparentUpgradeableContract(
        string memory moduleName_
    ) internal returns (address proxy_, address implementation_, address proxyAdmin_) {
        address proxyAdminOwner = getCommonContractsConfigTomlFile().readAddress(
            string.concat(".", moduleName_, ".owner")
        );

        // Basically, the encoder contract qualified path should be of the form:- <moduleName>.encoder.sol:<moduleName>Encoder
        EncoderBase encoder = EncoderBase(
            deployCode(string.concat(moduleName_, ".encoder.sol:", moduleName_, "Encoder"))
        );

        bytes memory encodedCallData = encoder.getEncodedCallData();

        vm.startBroadcast();
        proxy_ = Upgrades.deployTransparentProxy(string.concat(moduleName_, ".sol"), proxyAdminOwner, encodedCallData);
        vm.stopBroadcast();

        implementation_ = Upgrades.getImplementationAddress(proxy_);
        proxyAdmin_ = Upgrades.getAdminAddress(proxy_);

        _afterTransparentProxyDeployment(moduleName_, proxy_, implementation_, proxyAdmin_);
    }

    function deployImmutableContract(string memory moduleName_) internal returns (address contract_) {
        EncoderBase encoder = EncoderBase(
            deployCode(string.concat(moduleName_, ".encoder.sol:", moduleName_, "Encoder"))
        );

        bytes memory encodedCallData = encoder.getEncodedCallData();

        vm.startBroadcast();

        contract_ = deploy(string.concat(moduleName_, ".sol"), encodedCallData);

        vm.stopBroadcast();

        _afterImmutableDeployment(moduleName_, contract_);
    }

    /// @dev Adapted from OpenZeppelin's Foundry Upgrades package.
    ///      See the original implementation at: https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades/blob/359589365aeba6cf41d39bae69867446b194e582/src/Upgrades.sol#L487
    ///      This function has to be public to be able to broadcast the contract creation transaction.
    function deploy(string memory contractName_, bytes memory constructorData_) public returns (address) {
        bytes memory creationCode = vm.getCode(contractName_);
        address deployedAddress = _deployFromBytecode(abi.encodePacked(creationCode, constructorData_));

        if (deployedAddress == address(0)) {
            console2.log("Failed to deploy contract %s using the constructor data: ", contractName_);
            console2.logBytes(constructorData_);

            revert("Immutable contract deployment failed");
        }

        return deployedAddress;
    }

    function _afterTransparentProxyDeployment(
        string memory moduleName_,
        address proxy_,
        address implementation_,
        address proxyAdmin_
    ) internal virtual {
        string memory deploymentsFilePath = getCommonContractsDeploymentsFilePath();
        string memory existingDeployments = getCommonContractDeploymentsTomlFile();

        // Don't flatten the contracts or upload selectors related to the module if not broadcasting.
        if (_isBroadcasting) {
            flattenContract(moduleName_);
        }

        require(!vm.keyExistsToml(existingDeployments, string.concat(".", moduleName_)), "Module already exists");

        if (!vm.keyExistsToml(existingDeployments, string.concat(".", moduleName_))) {
            string memory objToAppend = string.concat(
                'proxy="',
                vm.toString(proxy_),
                '"\n',
                'implementation="',
                vm.toString(implementation_),
                '"\n',
                'proxyAdmin="',
                vm.toString(proxyAdmin_),
                '"\n',
                'commitHash="',
                vm.toString(getCommitHash()),
                '"\n\n'
            );

            vm.writeFile(deploymentsFilePath, string.concat(existingDeployments, "[", moduleName_, "]\n", objToAppend));
        } else {
            string memory moduleKey = string.concat(".", moduleName_);

            vm.writeToml(vm.toString(proxy_), deploymentsFilePath, string.concat(moduleKey, ".proxy"));
            vm.writeToml(
                vm.toString(implementation_),
                deploymentsFilePath,
                string.concat(moduleKey, ".implementation")
            );
            vm.writeToml(vm.toString(proxyAdmin_), deploymentsFilePath, string.concat(moduleKey, ".proxyAdmin"));
            vm.writeToml(vm.toString(getCommitHash()), deploymentsFilePath, string.concat(moduleKey, ".commitHash"));
        }
    }

    function _afterImmutableDeployment(string memory moduleName_, address contract_) internal virtual {
        string memory deploymentsFilePath = getCommonContractsDeploymentsFilePath();
        string memory existingDeployments = getCommonContractDeploymentsTomlFile();

        // Don't flatten the contracts or upload selectors related to the module if not broadcasting.
        if (_isBroadcasting) {
            flattenContract(moduleName_);
        }

        // If the module key does not exist in the deployments file, append the new key.
        // Otherwise, update the contract address and commit hash.
        if (!vm.keyExistsToml(existingDeployments, string.concat(".Modules.", moduleName_))) {
            string memory objToAppend = string.concat(
                'contract="',
                vm.toString(contract_),
                '"\n',
                'commitHash="',
                vm.toString(getCommitHash()),
                '"\n\n'
            );

            vm.writeFile(deploymentsFilePath, string.concat(existingDeployments, "[", moduleName_, "]\n", objToAppend));
        } else {
            string memory moduleKey = string.concat(".", moduleName_);

            vm.writeToml(vm.toString(contract_), deploymentsFilePath, string.concat(moduleKey, ".contract"));

            vm.writeToml(vm.toString(getCommitHash()), deploymentsFilePath, string.concat(moduleKey, ".commitHash"));
        }
    }

    function _deployFromBytecode(bytes memory bytecode) private returns (address) {
        address addr;
        assembly {
            addr := create(0, add(bytecode, 32), mload(bytecode))
        }
        return addr;
    }

    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }
}
