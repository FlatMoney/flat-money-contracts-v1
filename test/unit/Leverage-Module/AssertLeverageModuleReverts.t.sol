// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "../../helpers/OrderHelpers.sol";

contract AssertLeverageModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 0, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        DelayedOrderStructs.Order memory order;

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeOpen.selector, alice, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeAdjust.selector, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.executeClose.selector, order),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.burn.selector, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_leverage_criteria_value() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 1e18, 0),
            expectedErrorSignature: "InvalidLeverageCriteria()",
            errorData: abi.encodeWithSelector(LeverageModule.InvalidLeverageCriteria.selector)
        });

        _expectRevertWithCustomError({
            target: address(leverageModProxy),
            callData: abi.encodeWithSelector(leverageModProxy.setLeverageCriteria.selector, 0, 1e18, 1e18),
            expectedErrorSignature: "InvalidLeverageCriteria()",
            errorData: abi.encodeWithSelector(LeverageModule.InvalidLeverageCriteria.selector)
        });
    }

    function test_revert_leverage_open_for_zero_address() public {
        vm.startPrank(admin);

        // Add alice as an authorized caller.
        // This allows them to make certain announcements on behalf of other addresses.
        orderAnnouncementModProxy.addAuthorizedCaller(alice);

        // Deposit some collateral first.
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSignature(
                "announceOpenLeverageFor(address,address,uint256,uint256,uint256,uint256,uint256)",
                alice,
                address(0),
                100e18,
                100e18,
                0,
                type(uint256).max,
                0
            ),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroAddress.selector, "receiver")
        });
    }
}
