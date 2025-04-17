// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FlatZapper} from "../../../src/misc/FlatZapper/FlatZapper.sol";
import {ISwapper} from "../../../src/interfaces/ISwapper.sol";
import {IFlatcoinVault} from "../../../src/interfaces/IFlatcoinVault.sol";
import {IWETH} from "../../../src/interfaces/IWETH.sol";

import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract FlatZapperEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getConfigTomlFile();
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        IFlatcoinVault vault = IFlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));
        ISwapper swapper = ISwapper(getCommonContractDeploymentsTomlFile().readAddress(".Swapper.proxy"));
        address orderAnnouncementModule = deploymentsTomlFile.readAddress(".OrderAnnouncementModule.proxy");
        address owner = configTomlFile.readAddress(".Modules.FlatZapper.owner");
        IERC20 collateral = IERC20(configTomlFile.readAddress(".Modules.FlatZapper.collateral"));
        address permit2 = configTomlFile.readAddress(".Modules.FlatZapper.permit2");
        IWETH weth = IWETH(configTomlFile.readAddress(".Modules.FlatZapper.weth"));

        return
            abi.encodeCall(
                FlatZapper.initialize,
                (owner, vault, collateral, swapper, orderAnnouncementModule, permit2, weth)
            );
    }
}
