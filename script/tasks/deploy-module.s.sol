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

/// @title DeployModulesScript
/// @author dHEDGE
/// @notice Deployment script for deploying upgradeable and immutable contracts.
/// @dev The script assumes the following:
///      - The encoded initialization data can be retrieved from an encoder contract.
///      - The encoder contract file name should be the same as the module name with the suffix `.encoder.sol`.
///      - The encoder contract name should be the same as the module name with the suffix `Encoder`.
contract DeployModulesScript is BatchScript, InitScript, FFIHelpers {
    using stdToml for string;

    enum ProxyType {
        beacon,
        transparent
    }

    /// @notice Function to deploy all modules sequentially.
    /// @dev This is the only function that should be called directly by the script runner.
    /// @dev The `deploymentMode` modifier will revert the file changes in case the `_isBroadcasting` is `false`
    ///      or `_deploymentsSuccessful` is `false`.
    /// @param moduleNames_ The names of the modules to be deployed without the `.sol` extension.
    function deployModules(string[] memory moduleNames_) public virtual deploymentMode {
        try this.deployModulesExternal(moduleNames_) {
            _deploymentsSuccessful = true;
        } catch Error(string memory errorMessage) {
            console2.log(StdStyle.red(string.concat("Deployments failed with error:", errorMessage)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the deployment process"));
        }
    }

    /// @dev Should not be directly called by the script runner.
    function deployModulesExternal(string[] memory moduleNames_) external {
        require(msg.sender == address(this), "DeployScript: Only the script runner can call this function");

        string memory configFile = getConfigTomlFile();
        string memory commonContractsConfigFile = getCommonContractsConfigTomlFile();
        string memory commonContractsFile = getCommonContractDeploymentsTomlFile();

        for (uint8 i; i < moduleNames_.length; ++i) {
            string memory moduleName = moduleNames_[i];
            bool isCommonContract = vm.keyExistsToml(commonContractsConfigFile, string.concat(".", moduleName));

            // Check if the module is a common contract and if so, check if it is already deployed.
            // If it is, then skip the deployment process for the module.
            // A common contract must have an entry (as a TOML table) in the common contracts config file.
            if (isCommonContract && vm.keyExistsToml(commonContractsFile, string.concat(".", moduleName))) {
                console2.log(
                    StdStyle.yellow(
                        string.concat(
                            "Module ",
                            moduleName,
                            " is a common contract and deployed at address: ",
                            vm.toString(commonContractsFile.readAddress(string.concat(".", moduleName)))
                        )
                    )
                );

                continue;
            }

            // The way config of a contract is stored in the common contracts config file is different from the market config file.
            // In a market config file, the module config table is stored under the `Modules` table (See any market config file).
            string memory configKey = string.concat(".Modules.", moduleName);

            if (configFile.readBool(string.concat(configKey, ".isUpgradeable")) == false) {
                deployImmutableContract(moduleName);
            } else {
                if (_compareStrings(configFile.readString(string.concat(configKey, ".proxyType")), "beacon")) {
                    deployBeaconUpgradeableContract(moduleName);
                } else if (
                    _compareStrings(configFile.readString(string.concat(configKey, ".proxyType")), "transparent")
                ) {
                    deployTransparentUpgradeableContract(moduleName);
                } else {
                    revert("Invalid proxy type");
                }
            }
        }

        // If `_isBroadcasting` is true then execute the batch.
        // Otherwise just simulate the execution.
        if (encodedTxns.length != 0) executeBatch(configFile.readAddress(".owner"), _isBroadcasting);
    }

    /// @dev A beacon contract is assumed to never be a common contract.
    function deployBeacon(string memory moduleName_) internal returns (address beacon_) {
        string memory exstingBeacons = getBeaconsTomlFile();

        require(!vm.keyExistsToml(exstingBeacons, string.concat(".", moduleName_)), "Beacon already exists");

        vm.startBroadcast();
        beacon_ = Upgrades.deployBeacon(string.concat(moduleName_, ".sol"), getConfigTomlFile().readAddress(".owner"));
        vm.stopBroadcast();

        string memory beaconObjToAppend = string.concat(
            'beacon="',
            vm.toString(beacon_),
            '"\n',
            'implementation="',
            vm.toString(UpgradeableBeacon(beacon_).implementation()),
            '"\n',
            'commitHash="',
            vm.toString(getCommitHash()),
            '"\n\n'
        );

        // Add the new beacon for the module to the beacons file.
        vm.writeFile(getBeaconsFilePath(), string.concat(exstingBeacons, "[", moduleName_, "]\n", beaconObjToAppend));
    }

    /// @dev For deployment of Beacon Proxy upgradeable contracts.
    ///      A beacon contract is assumed to never be a common contract.
    function deployBeaconUpgradeableContract(
        string memory moduleName_
    ) internal returns (address proxy_, address implementation_) {
        string memory beaconFile = getBeaconsTomlFile();

        // Basically, the encoder contract qualified path should be of the form:- <moduleName>.encoder.sol:<moduleName>Encoder
        EncoderBase encoder = EncoderBase(
            deployCode(string.concat(moduleName_, ".encoder.sol:", moduleName_, "Encoder"))
        );

        bytes memory encodedCallData = encoder.getEncodedCallData();

        address beacon;
        if (!vm.keyExistsToml(beaconFile, string.concat(".", moduleName_))) {
            beacon = deployBeacon(moduleName_);
        } else {
            beacon = beaconFile.readAddress(string.concat(".", moduleName_, ".beacon"));
        }

        // Deploy the proxy contract.
        vm.startBroadcast();
        proxy_ = Upgrades.deployBeaconProxy(beacon, encodedCallData);
        vm.stopBroadcast();

        implementation_ = Upgrades.getImplementationAddress(proxy_);

        _afterBeaconProxyDeployment(moduleName_, proxy_);
    }

    /// @dev For deployment of Transparent Proxy upgradeable contracts.
    function deployTransparentUpgradeableContract(
        string memory moduleName_
    ) internal returns (address proxy_, address implementation_, address proxyAdmin_) {
        address proxyAdminOwner = getConfigTomlFile().readAddress(".owner");

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

    /// @dev A beacon contract is assumed to never be a common contract.
    function _afterBeaconProxyDeployment(string memory moduleName_, address proxy_) internal virtual {
        string memory deploymentFilePath = getModuleDeploymentsFilePath();
        string memory existingDeployments = getDeploymentsTomlFile();

        _tryAuthorizeModule(moduleName_, proxy_);

        // Don't flatten the contracts or upload selectors related to the module if not broadcasting.
        if (_isBroadcasting) {
            flattenContract(moduleName_);
        }

        // A module or beacon should not already exist in the deployments file for a given tag.
        require(
            !vm.keyExistsToml(existingDeployments, string.concat(".Modules.", moduleName_)),
            "Module already exists"
        );

        string memory moduleObjToAppend = string.concat('proxy="', vm.toString(proxy_), '"\n\n');

        vm.writeFile(
            deploymentFilePath,
            string.concat(existingDeployments, "[", moduleName_, "]\n", moduleObjToAppend)
        );
    }

    function _afterTransparentProxyDeployment(
        string memory moduleName_,
        address proxy_,
        address implementation_,
        address proxyAdmin_
    ) internal virtual {
        string memory deploymentsFilePath = getModuleDeploymentsFilePath();
        string memory existingDeployments = getDeploymentsTomlFile();

        _tryAuthorizeModule(moduleName_, proxy_);

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
        string memory deploymentsFilePath = getModuleDeploymentsFilePath();
        string memory existingDeployments = getDeploymentsTomlFile();

        _tryAuthorizeModule(moduleName_, contract_);

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

    function _tryAuthorizeModule(string memory moduleName_, address contract_) internal virtual {
        (bool success, bytes memory data) = (contract_).call(abi.encodeWithSignature("MODULE_KEY()"));

        if (!success) {
            console2.log(
                StdStyle.yellow(
                    string.concat(
                        "Module ",
                        moduleName_,
                        " does not have a MODULE_KEY() function. Please authorize this module manually if required."
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
