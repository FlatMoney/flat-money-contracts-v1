// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "../../helpers/Setup.sol";

contract ControllerBaseOwnerTest is Setup {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice));
        controllerModProxy.setMaxFundingVelocity(0);

        vm.expectRevert(abi.encodeWithSelector(ModuleUpgradeable.OnlyOwner.selector, alice));
        controllerModProxy.setMaxVelocitySkew(0);
    }

    function test_revert_when_wrong_max_velocity_skew_value() public {
        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(ControllerBase.InvalidMaxVelocitySkew.selector, 0));
        controllerModProxy.setMaxVelocitySkew(0);

        vm.expectRevert(abi.encodeWithSelector(ControllerBase.InvalidMaxVelocitySkew.selector, 2e18));
        controllerModProxy.setMaxVelocitySkew(2e18);
    }
}
