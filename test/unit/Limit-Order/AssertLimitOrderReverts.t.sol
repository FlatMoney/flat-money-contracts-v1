// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";

contract AssertLimitOrderRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(limitOrderProxy.cancelExistingLimitOrder.selector, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_module_paused() public {
        bytes32 moduleKey = limitOrderProxy.MODULE_KEY();

        vm.prank(admin);
        vaultProxy.pauseModule(moduleKey);

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(limitOrderProxy.announceLimitOrder.selector, 0, 0, 0),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.Paused.selector, moduleKey)
        });

        bytes[] memory emptyByteArray;

        _expectRevertWithCustomError({
            target: address(limitOrderProxy),
            callData: abi.encodeWithSelector(limitOrderProxy.executeLimitOrder.selector, 0, emptyByteArray),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.Paused.selector, moduleKey)
        });
    }
}
