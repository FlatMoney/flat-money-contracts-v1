// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {OptionsControllerModule} from "../../../src/OptionsControllerModule.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract OptionsControllerModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getConfigTomlFile();
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "OptionsControllerModuleEncoder: Vault address null");

        uint256 maxFundingVelocity = configTomlFile.readUint(".Modules.OptionsControllerModule.maxFundingVelocity");
        uint256 maxVelocitySkew = configTomlFile.readUint(".Modules.OptionsControllerModule.maxVelocitySkew");
        uint256 targetSizeCollateralRatio = configTomlFile.readUint(
            ".Modules.OptionsControllerModule.targetSizeCollateralRatio"
        );
        int256 minFundingRate = configTomlFile.readInt(".Modules.OptionsControllerModule.minFundingRate");

        return
            abi.encodeCall(
                OptionsControllerModule.initialize,
                (vault, maxFundingVelocity, maxVelocitySkew, targetSizeCollateralRatio, minFundingRate)
            );
    }
}
