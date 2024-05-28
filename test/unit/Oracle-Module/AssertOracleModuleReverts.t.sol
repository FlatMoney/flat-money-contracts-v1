// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "../../../src/libraries/FlatcoinStructs.sol";
import {IChainlinkAggregatorV3} from "../../../src/interfaces/IChainlinkAggregatorV3.sol";

contract AssertOracleModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        FlatcoinStructs.OnchainOracle memory onchainOracle;
        FlatcoinStructs.OffchainOracle memory offchainOracle;

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_wrong_max_diff_percent_value() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 0),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(oracleModProxy.setMaxDiffPercent.selector, 1.1e18),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });
    }

    function test_revert_when_wrong_asset_and_oracles_data() public {
        vm.startPrank(admin);

        FlatcoinStructs.OnchainOracle memory onchainOracle;
        FlatcoinStructs.OffchainOracle memory offchainOracle;

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                address(0),
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.ZeroAddress.selector, "asset")
        });

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        onchainOracle.oracleContract = IChainlinkAggregatorV3(alice);

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        onchainOracle.maxAge = 1;

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        offchainOracle.oracleContract = IPyth(alice);

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        offchainOracle.priceId = bytes32(uint256(1));

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        offchainOracle.maxAge = 1;

        _expectRevertWithCustomError({
            target: address(oracleModProxy),
            callData: abi.encodeWithSelector(
                oracleModProxy.setAssetAndOracles.selector,
                alice,
                onchainOracle,
                offchainOracle
            ),
            expectedErrorSignature: "OracleConfigInvalid()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OracleConfigInvalid.selector)
        });

        offchainOracle.minConfidenceRatio = 1;

        oracleModProxy.setAssetAndOracles(alice, onchainOracle, offchainOracle);
    }
}
