// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

contract AssertLimitOrderRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.deleteLimitOrder.selector, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_module_paused() public {
        bytes32 orderAnnouncementModKey = orderAnnouncementModProxy.MODULE_KEY();
        bytes32 orderExecutionModKey = orderExecutionModProxy.MODULE_KEY();

        // Create a market.
        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        vaultProxy.pauseModule(orderAnnouncementModKey);
        vaultProxy.pauseModule(orderExecutionModKey);

        vm.startPrank(alice);
        _expectRevertWithCustomError({
            target: address(orderAnnouncementModProxy),
            callData: abi.encodeWithSelector(orderAnnouncementModProxy.announceLimitOrder.selector, 0, 0, 0),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, orderAnnouncementModKey)
        });

        vm.startPrank(admin);
        // Unpause the order announcement module to create a valid limit order.
        vaultProxy.unpauseModule(orderAnnouncementModKey);

        vm.startPrank(alice);
        orderAnnouncementModProxy.announceLimitOrder(tokenId, 900e18, 1000e18);

        bytes[] memory emptyByteArray;

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(orderExecutionModProxy.executeLimitOrder.selector, 0, emptyByteArray),
            expectedErrorSignature: "Paused(bytes32)",
            errorData: abi.encodeWithSelector(ModuleUpgradeable.Paused.selector, orderExecutionModKey)
        });
    }
}
