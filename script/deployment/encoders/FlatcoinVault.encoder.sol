// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {FlatcoinVault} from "../../../src/FlatcoinVault.sol";
import "../misc/EncoderBase.sol";

import "forge-std/StdToml.sol";

contract FlatcoinVaultEncoder is EncoderBase {
    using stdToml for string;

    function getEncodedCallData() public override returns (bytes memory) {
        string memory tomlFile = getConfigTomlFile();

        address collateral = tomlFile.readAddress(".Modules.FlatcoinVault.collateral");
        address protocolFeeRecipient = tomlFile.readAddress(".Modules.FlatcoinVault.protocolFeeRecipient");
        uint64 protocolFeePercentage = uint64(tomlFile.readUint(".Modules.FlatcoinVault.protocolFeePercentage"));
        uint64 leverageTradingFee = uint64(tomlFile.readUint(".Modules.FlatcoinVault.leverageTradingFee"));
        uint64 stableWithdrawFee = uint64(tomlFile.readUint(".Modules.FlatcoinVault.stableWithdrawFee"));
        uint256 maxDeltaError = tomlFile.readUint(".Modules.FlatcoinVault.maxDeltaError");
        uint256 skewFractionMax = tomlFile.readUint(".Modules.FlatcoinVault.skewFractionMax");
        uint256 stableCollateralCap = tomlFile.readUint(".Modules.FlatcoinVault.stableCollateralCap");
        uint256 maxPositions = tomlFile.readUint(".Modules.FlatcoinVault.maxPositions");

        return
            abi.encodeCall(
                FlatcoinVault.initialize,
                (
                    IERC20Metadata(collateral),
                    protocolFeeRecipient,
                    protocolFeePercentage,
                    leverageTradingFee,
                    stableWithdrawFee,
                    maxDeltaError,
                    skewFractionMax,
                    stableCollateralCap,
                    maxPositions
                )
            );
    }
}
