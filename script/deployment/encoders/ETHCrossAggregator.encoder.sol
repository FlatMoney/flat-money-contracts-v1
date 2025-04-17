// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract ETHCrossAggregatorEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory tomlFile = getConfigTomlFile();

        return
            abi.encode(
                tomlFile.readAddress(".Modules.ETHCrossAggregator.token"),
                tomlFile.readAddress(".Modules.ETHCrossAggregator.tokenToEthAggregator"),
                tomlFile.readAddress(".Modules.ETHCrossAggregator.ethToUsdAggregator"),
                tomlFile.readUint(".Modules.ETHCrossAggregator.tokenToEthPriceMaxAge")
            );
    }
}
