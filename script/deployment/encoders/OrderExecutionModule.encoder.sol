// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {OrderExecutionModule} from "../../../src/OrderExecutionModule.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract OrderExecutionModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "OrderExecutionModule: Vault address null");

        return
            abi.encodeCall(
                OrderExecutionModule.initialize,
                (vault, uint64(getConfigTomlFile().readUint(".Modules.OrderExecutionModule.maxExecutabilityAge")))
            );
    }
}
