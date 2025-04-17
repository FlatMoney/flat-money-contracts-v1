// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {OptionViewer} from "../../../src/misc/OptionViewer.sol";
import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract OptionViewerEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "OptionViewerEncoder: Vault address null");

        return abi.encode(vault);
    }
}
