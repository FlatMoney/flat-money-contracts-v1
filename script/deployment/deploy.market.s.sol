// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {FlatcoinModuleKeys} from "../../src/libraries/FlatcoinModuleKeys.sol";
import {FlatcoinVault} from "../../src/FlatcoinVault.sol";

import {FileManager} from "../utils/FileManager.sol";
import "../tasks/deploy-module.s.sol";

import "forge-std/Script.sol";
import "forge-std/StdToml.sol";

contract DeployMarketScript is InitScript, DeployModulesScript {
    using stdToml for string;

    FlatcoinVaultStructs.AuthorizedModule[] private authorizedModules;
    string[] private moduleNames;

    function run() public deploymentMode {
        console2.log("Deployer address: ", msg.sender);

        try this.runExternal() {
            _deploymentsSuccessful = true;
        } catch Error(string memory reason) {
            console2.log(StdStyle.red(string.concat("Protocol deployment failed: ", reason)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the deployment process"));
        }
    }

    /// @dev Note that this script doesn't do common contract deployments.
    ///      If a market requires common contracts, they should be deployed separately.
    function runExternal() external {
        require(msg.sender == address(this), "DeployMarketScript: runExternal can only be called by this contract");

        string memory configFile = getConfigTomlFile();

        moduleNames = vm.parseTomlKeys(configFile, ".Modules");
        address protocolOwner = configFile.readAddress(".owner");

        console2.log("Modules length: %d", moduleNames.length);

        deployModules(moduleNames);

        string memory deploymentsFile = getDeploymentsTomlFile();
        string memory commonContractsFile = getCommonContractDeploymentsTomlFile();

        address vaultProxy = deploymentsFile.readAddress(".FlatcoinVault.proxy");
        address oracleModule = commonContractsFile.readAddress(".OracleModule.proxy");
        address orderAnnouncementModProxy = deploymentsFile.readAddress(".OrderAnnouncementModule.proxy");
        address zapperProxy = deploymentsFile.readAddress(".FlatZapper.proxy");

        // Since the OracleModule is a common contract, we need to authorize it manually for the new market.
        _tryAuthorizeModule("OracleModule", oracleModule);

        vm.startBroadcast();

        // Authorize all the modules.
        FlatcoinVault(vaultProxy).addAuthorizedModules(authorizedModules);

        // Authorize the FlatZapper contract for `announceXFor` functions usage.
        OrderAnnouncementModule(orderAnnouncementModProxy).addAuthorizedCaller(zapperProxy);

        // Transfer the vault control from deployer to the protocol owner.
        FlatcoinVault(vaultProxy).transferOwnership(protocolOwner);

        require(FlatcoinVault(vaultProxy).owner() == configFile.readAddress(".owner"), "Vault owner mismatch");

        vm.stopBroadcast();
    }

    function deployModules(string[] memory moduleNames_) public override {
        try this.deployModulesExternal(moduleNames_) {
            _deploymentsSuccessful = true;
        } catch Error(string memory errorMessage) {
            console2.log(StdStyle.red(string.concat("Deployments failed with error:", errorMessage)));
        } catch {
            console2.log(StdStyle.red("An error occurred during the deployment process"));
        }
    }

    function _tryAuthorizeModule(string memory moduleName_, address module_) internal override {
        (bool success, bytes memory data) = (module_).call(abi.encodeWithSignature("MODULE_KEY()"));

        if (success) {
            bytes32 moduleKey = abi.decode(data, (bytes32));

            authorizedModules.push(
                FlatcoinVaultStructs.AuthorizedModule({moduleAddress: module_, moduleKey: moduleKey})
            );
        } else {
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
        }
    }
}
