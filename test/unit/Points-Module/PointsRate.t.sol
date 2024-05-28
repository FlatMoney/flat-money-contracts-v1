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

contract PointsRateTest is Setup, OrderHelpers, ExpectRevert {
    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        vaultProxy.setSkewFractionMax(100e18); // effectively disable skew fraction
        assertEq(pointsModProxy.getAvailableMint(), 100_000e18);
    }

    function test_points_mint_receive_half_rate_limit() public {
        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 2_000e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 100_000e18);
        assertEq(pointsModProxy.getAccumulatedMint(), 100_000e18);
        assertEq(pointsModProxy.getAvailableMint(), 0);
    }

    function test_points_mint_not_received_on_stable_deposit_rate_limit() public {
        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1_000e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 100_000e18);
        assertEq(pointsModProxy.getAccumulatedMint(), 100_000e18);
        assertEq(pointsModProxy.getAvailableMint(), 0);

        // Rate limit reached
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(pointsModProxy.balanceOf(alice), 100_000e18, 20e18); // some small amount of points minted due to time delay
        uint256 additionalPointsMinted = pointsModProxy.balanceOf(alice) - 100_000e18;

        skip(12 hours);
        setWethPrice(2000e8);

        assertApproxEqRel(pointsModProxy.getAvailableMint(), 50_000e18, 0.0003e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 500e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 150_000e18 + additionalPointsMinted);
        assertApproxEqRel(pointsModProxy.getAccumulatedMint(), 100_000e18, 0.0003e18); // some seconds have passed and accumulated mint decayed slightly

        skip(25 hours);
        setWethPrice(2000e8);

        assertEq(pointsModProxy.getAccumulatedMint(), 0);
        assertEq(pointsModProxy.getAvailableMint(), 100_000e18);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1_000e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 250_000e18 + additionalPointsMinted);
        assertEq(pointsModProxy.getAccumulatedMint(), 100_000e18);
    }

    function test_points_mint_not_received_on_leverage_open_rate_limit() public {
        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 500e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 50_000e18);
        assertEq(pointsModProxy.getAccumulatedMint(), 50_000e18);
        assertEq(pointsModProxy.getAvailableMint(), 50_000e18);

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 250e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 100_000e18);
        assertApproxEqRel(pointsModProxy.getAccumulatedMint(), 100_000e18, 0.0001e18); // some seconds have passed and accumulated mint decayed slightly
        assertApproxEqAbs(pointsModProxy.getAvailableMint(), 0, 10e18);

        // Rate limit reached
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 1e18,
            additionalSize: 1e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(pointsModProxy.balanceOf(alice), 100_000e18, 20e18); // some small amount of points minted due to time delay
        uint256 additionalPointsMinted = pointsModProxy.balanceOf(alice) - 100_000e18;

        skip(12 hours);
        setWethPrice(2000e8);

        assertApproxEqRel(pointsModProxy.getAvailableMint(), 50_000e18, 0.0004e18);

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 250e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 150_000e18 + additionalPointsMinted);
        assertApproxEqRel(pointsModProxy.getAccumulatedMint(), 100_000e18, 0.0003e18); // some seconds have passed and accumulated mint decayed slightly
        assertApproxEqAbs(pointsModProxy.getAvailableMint(), 0, 30e18);

        skip(25 hours);
        setWethPrice(2000e8);

        assertEq(pointsModProxy.getAccumulatedMint(), 0);
        assertEq(pointsModProxy.getAvailableMint(), 100_000e18);

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 500e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 250_000e18 + additionalPointsMinted);
        assertEq(pointsModProxy.getAccumulatedMint(), 100_000e18);
        assertEq(pointsModProxy.getAvailableMint(), 0);
    }

    function test_points_mint_not_received_on_leverage_adjust_rate_limit() public {
        uint256 depositAmount = 500e18;

        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 100 * depositAmount);
        assertEq(pointsModProxy.getAccumulatedMint(), 100 * depositAmount);
        assertEq(pointsModProxy.getAvailableMint(), 50_000e18);

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 250e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 100_000e18);
        assertApproxEqRel(pointsModProxy.getAccumulatedMint(), 100_000e18, 0.0001e18); // some seconds have passed and accumulated mint decayed slightly
        assertApproxEqAbs(pointsModProxy.getAvailableMint(), 0, 10e18);

        // Rate limit reached
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 1e18,
            additionalSizeAdjustment: 1e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(pointsModProxy.balanceOf(alice), 100_000e18, 20e18); // some small amount of points minted due to time delay
        uint256 additionalPointsMinted = pointsModProxy.balanceOf(alice) - 100_000e18;

        skip(12 hours);
        setWethPrice(2000e8);

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 250e18,
            additionalSizeAdjustment: 250e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 150_000e18 + additionalPointsMinted);
        assertApproxEqRel(pointsModProxy.getAccumulatedMint(), 100_000e18, 0.0003e18); // some seconds have passed and accumulated mint decayed slightly
        assertApproxEqAbs(pointsModProxy.getAvailableMint(), 0, 30e18);

        skip(25 hours);
        setWethPrice(2000e8);

        assertEq(pointsModProxy.getAccumulatedMint(), 0);
        assertEq(pointsModProxy.getAvailableMint(), 100_000e18);

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 500e18,
            additionalSizeAdjustment: 500e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.balanceOf(alice), 250_000e18 + additionalPointsMinted);
        assertEq(pointsModProxy.getAccumulatedMint(), 100_000e18);
        assertEq(pointsModProxy.getAvailableMint(), 0);
    }

    function test_points_mint_decay() public {
        uint256 depositAmount = 100e18;

        vm.startPrank(alice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: depositAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        assertEq(pointsModProxy.getAccumulatedMint(), 100 * depositAmount);

        skip(12 hours);

        assertEq(pointsModProxy.getAccumulatedMint(), 50 * depositAmount);

        skip(12 hours);

        assertEq(pointsModProxy.getAccumulatedMint(), 0);
    }
}
