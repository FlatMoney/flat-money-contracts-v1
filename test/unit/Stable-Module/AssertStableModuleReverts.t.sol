// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "../../../src/libraries/FlatcoinStructs.sol";

contract AssertPointsModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.setStableWithdrawFee.selector, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        FlatcoinStructs.AnnouncedStableDeposit memory deposit;

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.executeDeposit.selector, alice, 0, deposit),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        FlatcoinStructs.AnnouncedStableWithdraw memory withdraw;

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.executeWithdraw.selector, alice, 0, withdraw),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.lock.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.unlock.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_withdraw_fee() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.setStableWithdrawFee.selector, 1e18),
            expectedErrorSignature: "InvalidFee(uint256)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.InvalidFee.selector, 1e18)
        });
    }
}
