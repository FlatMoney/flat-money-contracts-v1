// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";
import {IPointsModule} from "../../../src/interfaces/IPointsModule.sol";

contract AssertPointsModuleRevertsTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        IPointsModule.MintPoints memory points;

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.mintTo.selector, points),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.mintToMultiple.selector, points),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.setTreasury.selector, address(0)),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.setPointsVest.selector, 0, 0, 0),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.mintLeverageOpen.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.mintDeposit.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_treasury_address() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(pointsModProxy.setTreasury.selector, address(0)),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.ZeroAddress.selector, "treasury")
        });
    }
}
