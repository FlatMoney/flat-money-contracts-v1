// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

contract AssertStableModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setStableWithdrawFee.selector, 0),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        DelayedOrderStructs.AnnouncedStableDeposit memory deposit;

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.executeDeposit.selector, alice, 0, deposit),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        DelayedOrderStructs.AnnouncedStableWithdraw memory withdraw;

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.executeWithdraw.selector, alice, 0, withdraw),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.lock.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(stableModProxy),
            callData: abi.encodeWithSelector(stableModProxy.unlock.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_withdraw_fee() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setStableWithdrawFee.selector, 1.1e18),
            expectedErrorSignature: "InvalidPercentageValue(uint64)",
            errorData: abi.encodeWithSelector(ICommonErrors.InvalidPercentageValue.selector, 1.1e18)
        });
    }

    function test_revert_deposit_announcement_on_behalf_of_address_zero() public {
        vm.startPrank(admin);

        // Add alice as an authorized caller.
        // This allows them to make certain announcements on behalf of other addresses.
        orderAnnouncementModProxy.addAuthorizedCaller(alice);

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeCall(this.announceStableDepositFor, (alice, address(0), 1e18, 0)),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSignature("ZeroAddress(string)", "receiver")
        });
    }
}
