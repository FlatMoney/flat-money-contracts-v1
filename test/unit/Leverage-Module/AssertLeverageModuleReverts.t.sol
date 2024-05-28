// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "../../../src/libraries/FlatcoinStructs.sol";

contract AssertLeverageModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageTradingFee.selector, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 0, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        FlatcoinStructs.Order memory order;

        bytes32 moduleKey = delayedOrderProxy.MODULE_KEY();

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeOpen.selector, alice, bob, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeAdjust.selector, alice, bob, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeClose.selector, alice, bob, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.burn.selector, 0, moduleKey),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.lock.selector, 0, moduleKey),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.unlock.selector, 0, moduleKey),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_leverage_trading_fee_value() public {
        vm.startPrank(admin);

        // 100% fee
        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageTradingFee.selector, 1e18),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidFee.selector, 1e18)
        });

        // 10% fee
        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageTradingFee.selector, 0.1e18),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidFee.selector, 0.1e18)
        });
    }

    function test_revert_when_wrong_leverage_criteria_value() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 1e18, 0),
            expectedErrorSignature: "InvalidLeverageCriteria()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidLeverageCriteria.selector)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 1e18, 1e18),
            expectedErrorSignature: "InvalidLeverageCriteria()",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidLeverageCriteria.selector)
        });
    }
}
