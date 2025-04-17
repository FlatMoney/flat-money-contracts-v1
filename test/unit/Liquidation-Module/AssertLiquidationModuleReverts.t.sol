// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "../../helpers/OrderHelpers.sol";

contract AssertLiquidationModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeRatio.selector, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationBufferRatio.selector, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeBounds.selector, 0, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_module_paused() public {
        bytes32 moduleKey = liquidationModProxy.MODULE_KEY();

        vm.prank(admin);
        vaultProxy.pauseModule(moduleKey);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(bytes4(keccak256("liquidate(uint256[])")), tokenIds),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, moduleKey)
        });
    }

    function test_revert_when_wrong_liquidation_fee_ratio_value() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeRatio.selector, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "newLiquidationFeeRatio")
        });
    }

    function test_revert_when_wrong_liquidation_buffer_ratio_value() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationBufferRatio.selector, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "newLiquidationBufferRatio")
        });
    }

    function test_revert_when_wrong_liquidation_fee_bounds_values() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeBounds.selector, 0, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "newLiquidationFee")
        });

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeBounds.selector, 1e18, 0),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "newLiquidationFee")
        });

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeBounds.selector, 0, 1e18),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "newLiquidationFee")
        });

        _expectRevertWithCustomError({
            target: address(liquidationModProxy),
            callData: abi.encodeWithSelector(liquidationModProxy.setLiquidationFeeBounds.selector, 1e18, 0.1e18),
            expectedErrorSignature: "InvalidBounds(uint256,uint256)",
            errorData: abi.encodeWithSelector(LiquidationModule.InvalidBounds.selector, 1e18, 0.1e18)
        });
    }
}
