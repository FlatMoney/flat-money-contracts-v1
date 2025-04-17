// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

import "src/interfaces/IChainlinkAggregatorV3.sol";

import "forge-std/console2.sol";

contract MaxVelocitySkewTest is OrderHelpers, ExpectRevert {
    function setUp() public override {
        super.setUp();

        disableChainlinkExpiry();
    }

    function test_max_velocity_skew_long() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 120e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.003e18);
        controllerModProxy.setMaxVelocitySkew(0.1e18);

        skip(1 days);

        // With 20% skew, the funding rate velocity should be at maximum
        assertEq(controllerModProxy.currentFundingRate(), 0.003e18, "Incorrect funding rate");
    }

    function test_max_velocity_skew_short() public {
        setCollateralPrice(1000e8);

        uint256 collateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 80e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.003e18);
        controllerModProxy.setMaxVelocitySkew(0.01e18);

        skip(1 days);

        // With -20% skew, the funding rate velocity should be at maximum
        assertEq(controllerModProxy.currentFundingRate(), -0.003e18, "Incorrect funding rate");

        uint256 expectedStableCollateralPerShare = collateralPerShareBefore -
            ((collateralPerShareBefore * ((0.003e18 / 2) * 80)) / 100e18);
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            expectedStableCollateralPerShare,
            "Incorrect stable collateral per share"
        );

        orderAnnouncementModProxy.setMinExecutabilityAge(1); // minimum delay to keep the accrued funding close to being round and clean
        orderExecutionModProxy.setMaxExecutabilityAge(60);

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        skip(1 days);

        int256 expectedFunding = -0.006e18 - (int256(0.003e18) / 1 days); // additional 1 second of funding for order exeution
        assertEq(controllerModProxy.currentFundingRate(), expectedFunding, "Incorrect funding rate");
    }

    function test_max_velocity_skew_long_half() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 105e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.003e18);
        controllerModProxy.setMaxVelocitySkew(0.1e18);

        skip(1 days);

        // With 5% skew, the funding rate velocity should be half the maximum
        assertEq(controllerModProxy.currentFundingRate(), 0.0015e18, "Incorrect funding rate");
    }

    function test_max_velocity_skew_short_half() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 50e18,
            additionalSize: 95e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);
        controllerModProxy.setMaxFundingVelocity(0.003e18);
        controllerModProxy.setMaxVelocitySkew(0.1e18);

        skip(1 days);

        // With 5% skew, the funding rate velocity should be half the maximum
        assertEq(controllerModProxy.currentFundingRate(), -0.0015e18, "Incorrect funding rate");
    }
}
