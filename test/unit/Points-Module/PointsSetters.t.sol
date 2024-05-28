// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Setup} from "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {PointsModule} from "src/PointsModule.sol";
import {FlatcoinModuleKeys} from "src/libraries/FlatcoinModuleKeys.sol";
import {FlatcoinStructs} from "src/libraries/FlatcoinStructs.sol";
import {FlatcoinErrors} from "src/libraries/FlatcoinErrors.sol";
import {IPointsModule} from "src/interfaces/IPointsModule.sol";

import "forge-std/console2.sol";

contract PointsSettersTest is Setup, OrderHelpers, ExpectRevert {
    function test_points_setters() public {
        vm.startPrank(admin);

        pointsModProxy.setPointsVest(366 days);
        pointsModProxy.setPointsMint(1000e18, 2000e18);
        pointsModProxy.setTreasury(bob);
        pointsModProxy.setMintRate({_maxAccumulatedMint: 100e18, _decayTime: 12 hours});
        (, uint256 maxAccumulatedMint, , uint64 delayTime) = pointsModProxy.mintRate();

        assertEq(pointsModProxy.unlockTaxVest(), 366 days);
        assertEq(pointsModProxy.pointsPerSize(), 1000e18);
        assertEq(pointsModProxy.pointsPerDeposit(), 2000e18);
        assertEq(pointsModProxy.treasury(), bob);
        assertEq(maxAccumulatedMint, 100e18);
        assertEq(delayTime, 12 hours);
    }

    function test_points_set_decrease_vest_0_percent_vesting() public {
        vm.startPrank(admin);

        PointsModule.MintPoints memory mintParams = PointsModule.MintPoints({to: alice, amount: 200e18});
        pointsModProxy.mintTo(mintParams);

        // set unlock vest to 5 months
        _changeVestTo(150 days);

        assertEq(pointsModProxy.getUnlockTax(alice), 1e18, "Should cap unlock tax at 100%");

        skip(365 days / 2); // 6 months later

        vm.startPrank(alice);

        pointsModProxy.unlock(type(uint256).max);

        // Note: When decreasing vest time, the unlock ramp is delayed
        assertEq(pointsModProxy.balanceOf(alice), 0);
        assertEq(pointsModProxy.balanceOf(treasury), 200e18);
        assertEq(pointsModProxy.lockedBalance(alice), 0);
        assertEq(pointsModProxy.unlockTime(alice), 0);
        assertEq(pointsModProxy.getUnlockTax(alice), 0);
    }

    function test_points_set_decrease_vest_50_percent_vesting() public {
        vm.startPrank(admin);

        PointsModule.MintPoints memory mintParams = PointsModule.MintPoints({to: alice, amount: 200e18});
        pointsModProxy.mintTo(mintParams);

        // set unlock vest to 5 months
        _changeVestTo(150 days);

        skip(365 days - 75 days); // >6 months later

        vm.startPrank(alice);

        pointsModProxy.unlock(type(uint256).max);

        // Note: When decreasing vest time, it takes longer to get to 50% unlock
        assertEq(pointsModProxy.balanceOf(alice), 100e18);
        assertEq(pointsModProxy.balanceOf(treasury), 100e18);
        assertEq(pointsModProxy.lockedBalance(alice), 0);
        assertEq(pointsModProxy.unlockTime(alice), 0);
        assertEq(pointsModProxy.getUnlockTax(alice), 0);
    }

    function test_points_set_increase_vest_50_percent_vesting() public {
        vm.startPrank(admin);

        PointsModule.MintPoints memory mintParams = PointsModule.MintPoints({to: alice, amount: 200e18});
        pointsModProxy.mintTo(mintParams);

        // set unlock vest to 2 years
        _changeVestTo(365 days * 2);

        vm.startPrank(alice);

        pointsModProxy.unlock(type(uint256).max);

        // Note: When doubling the vest time, 50% of newly minted points are unlocked immediately
        assertEq(pointsModProxy.balanceOf(alice), 100e18);
        assertEq(pointsModProxy.balanceOf(treasury), 100e18);
        assertEq(pointsModProxy.lockedBalance(alice), 0);
        assertEq(pointsModProxy.unlockTime(alice), 0);
        assertEq(pointsModProxy.getUnlockTax(alice), 0);
    }

    function test_points_set_decrease_vest_remint() public {
        vm.startPrank(admin);

        PointsModule.MintPoints memory mintParams = PointsModule.MintPoints({to: alice, amount: 100e18});
        pointsModProxy.mintTo(mintParams);

        uint256 unlockTimeBefore = pointsModProxy.unlockTime(alice);

        // set unlock vest to 6 months
        _changeVestTo(365 days / 2);

        mintParams = PointsModule.MintPoints({to: alice, amount: 100e18});
        pointsModProxy.mintTo(mintParams);

        uint256 unlockTimeAfter = pointsModProxy.unlockTime(alice);

        vm.startPrank(alice);

        skip(365 days / 2);

        pointsModProxy.unlock(type(uint256).max);

        // 50% of tokens vested after 6 months (9 months for full vest)
        assertApproxEqAbs((unlockTimeBefore * 3) / 4, unlockTimeAfter, 1);
        assertEq(pointsModProxy.balanceOf(alice), 100e18);
        assertEq(pointsModProxy.balanceOf(treasury), 100e18);
        assertEq(pointsModProxy.lockedBalance(alice), 0);
        assertEq(pointsModProxy.unlockTime(alice), 0);
        assertEq(pointsModProxy.getUnlockTax(alice), 0);
    }

    function test_points_set_increase_vest_remint() public {
        vm.startPrank(admin);

        PointsModule.MintPoints memory mintParams = PointsModule.MintPoints({to: alice, amount: 100e18});
        pointsModProxy.mintTo(mintParams);

        uint256 unlockTimeBefore = pointsModProxy.unlockTime(alice);

        // set unlock vest to 2 years
        _changeVestTo(365 days * 2);

        mintParams = PointsModule.MintPoints({to: alice, amount: 100e18});
        pointsModProxy.mintTo(mintParams);

        uint256 unlockTimeAfter = pointsModProxy.unlockTime(alice);

        vm.startPrank(alice);

        skip(365 days / 2);

        pointsModProxy.unlock(type(uint256).max);

        // 50% of tokens vested after 6 months (1.5 years for full vest)
        assertApproxEqAbs((unlockTimeBefore * 3) / 2, unlockTimeAfter, 1);
        assertEq(pointsModProxy.balanceOf(alice), 100e18);
        assertEq(pointsModProxy.balanceOf(treasury), 100e18);
        assertEq(pointsModProxy.lockedBalance(alice), 0);
        assertEq(pointsModProxy.unlockTime(alice), 0);
        assertEq(pointsModProxy.getUnlockTax(alice), 0);
    }

    /**
     * Reverts
     */

    function test_revert_points_setters_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setPointsMint.selector, 1000e18, 2000e18),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setPointsVest.selector, 86300e18),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setTreasury.selector, bob),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setMintRate.selector, 100e18, 12 hours),
            expectedErrorSignature: "OnlyOwner(address)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.OnlyOwner.selector, alice)
        });
    }

    function test_revert_points_vest_variance() public {
        vm.startPrank(admin);

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setPointsVest.selector, 250 days),
            expectedErrorSignature: "MaxVarianceExceeded(string)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxVarianceExceeded.selector, "unlockTaxVest")
        });

        _expectRevertWithCustomError({
            target: address(pointsModProxy),
            callData: abi.encodeWithSelector(PointsModule.setPointsVest.selector, 450 days),
            expectedErrorSignature: "MaxVarianceExceeded(string)",
            errorData: abi.encodeWithSelector(FlatcoinErrors.MaxVarianceExceeded.selector, "unlockTaxVest")
        });
    }

    /**
     * Internal helper functions
     */

    /// @dev Change unlock vest to `_unlockTaxVest` 10% per change as per function requirement
    function _changeVestTo(uint256 _unlockTaxVest) internal {
        if (_unlockTaxVest < pointsModProxy.unlockTaxVest()) {
            // Decrease vest time
            while (pointsModProxy.unlockTaxVest() > _unlockTaxVest) {
                pointsModProxy.setPointsVest({_unlockTaxVest: (pointsModProxy.unlockTaxVest() * 0.9e18) / 1e18});

                if (pointsModProxy.unlockTaxVest() < _unlockTaxVest) {
                    pointsModProxy.setPointsVest({_unlockTaxVest: _unlockTaxVest});
                    break;
                }
            }
        } else {
            // Increase vest time
            while (pointsModProxy.unlockTaxVest() < _unlockTaxVest) {
                pointsModProxy.setPointsVest({_unlockTaxVest: (pointsModProxy.unlockTaxVest() * 1.1e18) / 1e18});

                if (pointsModProxy.unlockTaxVest() > _unlockTaxVest) {
                    pointsModProxy.setPointsVest({_unlockTaxVest: _unlockTaxVest});
                    break;
                }
            }
        }
    }
}
