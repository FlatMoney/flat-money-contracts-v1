// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

contract AssertOracleModuleRevertsTest is OrderHelpers, ExpectRevert {
    // function test_revert_when_caller_not_owner() public {
    //     vm.startPrank(alice);
    //     OracleModuleStructs.OnchainOracle memory onchainOracle;
    //     OracleModuleStructs.OffchainOracle memory offchainOracle;
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OnlyOwner(address)",
    //         errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
    //     });
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 0),
    //         expectedErrorSignature: "OnlyOwner(address)",
    //         errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
    //     });
    // }
    // function test_revert_when_wrong_max_diff_percent_value() public {
    //     vm.startPrank(admin);
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 0),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 1.1e18),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    // }
    // function test_revert_when_wrong_asset_and_oracles_data() public {
    //     vm.startPrank(admin);
    //     OracleModuleStructs.OnchainOracle memory onchainOracle;
    //     OracleModuleStructs.OffchainOracle memory offchainOracle;
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             address(0),
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "ZeroAddress(string)",
    //         errorData: abi.encodeWithSelector(ICommonErrors.ZeroAddress.selector, "asset")
    //     });
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     onchainOracle.oracleContract = IChainlinkAggregatorV3(alice);
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     onchainOracle.maxAge = 1;
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     offchainOracle.oracleContract = IPyth(alice);
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     offchainOracle.priceId = bytes32(uint256(1));
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     offchainOracle.maxAge = 1;
    //     _expectRevertWithCustomError({
    //         target: address(oracleModProxy),
    //         callData: abi.encodeWithSelector(
    //             oracleModProxy.setAssetAndOracles.selector,
    //             alice,
    //             onchainOracle,
    //             offchainOracle
    //         ),
    //         expectedErrorSignature: "OracleConfigInvalid()",
    //         errorData: abi.encodeWithSelector(OracleModule.OracleConfigInvalid.selector)
    //     });
    //     offchainOracle.minConfidenceRatio = 1;
    //     oracleModProxy.setAssetAndOracles(alice, onchainOracle, offchainOracle);
    // }
}
