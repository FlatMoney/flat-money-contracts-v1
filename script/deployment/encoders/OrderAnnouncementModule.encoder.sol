// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {OrderAnnouncementModule} from "../../../src/OrderAnnouncementModule.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract OrderAnnouncementModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory deploymentsTomlFile = getDeploymentsTomlFile();
        string memory configTomlFile = getConfigTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "OrderAnnouncementModuleEncoder: Vault address null");

        return
            abi.encodeCall(
                OrderAnnouncementModule.initialize,
                (
                    vault,
                    uint128(configTomlFile.readUint(".Modules.OrderAnnouncementModule.minDepositAmountUSD")),
                    uint64(configTomlFile.readUint(".Modules.OrderAnnouncementModule.minExecutabilityAge"))
                )
            );
    }
}
