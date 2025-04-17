// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import {PerpControllerModule} from "../../../src/PerpControllerModule.sol";
import {EncoderBase} from "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract PerpControllerModuleEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory configTomlFile = getConfigTomlFile();
        string memory deploymentsTomlFile = getDeploymentsTomlFile();

        FlatcoinVault vault = FlatcoinVault(deploymentsTomlFile.readAddress(".FlatcoinVault.proxy"));

        require(address(vault) != address(0), "ControllerModuleEncoder: Vault address null");

        uint256 maxFundingVelocity = configTomlFile.readUint(".Modules.PerpControllerModule.maxFundingVelocity");
        uint256 maxVelocitySkew = configTomlFile.readUint(".Modules.PerpControllerModule.maxVelocitySkew");
        uint256 targetSizeCollateralRatio = configTomlFile.readUint(
            ".Modules.PerpControllerModule.targetSizeCollateralRatio"
        );
        int256 minFundingRate = configTomlFile.readInt(".Modules.PerpControllerModule.minFundingRate");

        return
            abi.encodeCall(
                PerpControllerModule.initialize,
                (vault, maxFundingVelocity, maxVelocitySkew, targetSizeCollateralRatio, minFundingRate)
            );
    }
}
