// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Swapper} from "../../../src/misc/Swapper/Swapper.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";
import {IWETH} from "../../../src/interfaces/IWETH.sol";

import "forge-std/StdToml.sol";

contract SwapperEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getCommonContractsConfigTomlFile();

        address owner = configTomlFile.readAddress(".Swapper.owner");
        address permit2 = configTomlFile.readAddress(".Swapper.permit2");
        IWETH weth = IWETH(configTomlFile.readAddress(".Swapper.weth"));

        return abi.encodeCall(Swapper.initialize, (owner, permit2, weth));
    }
}
