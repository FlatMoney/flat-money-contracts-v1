// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {LeverageModule} from "../../../src/LeverageModule.sol";
import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract LeverageModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory tomlFile = getConfigTomlFile();
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "LeverageModuleEncoder: Vault address null");

        return
            abi.encodeCall(
                LeverageModule.initialize,
                (
                    vault,
                    tomlFile.readUint(".Modules.LeverageModule.marginMin"),
                    tomlFile.readUint(".Modules.LeverageModule.leverageMin"),
                    tomlFile.readUint(".Modules.LeverageModule.leverageMax")
                )
            );
    }
}
