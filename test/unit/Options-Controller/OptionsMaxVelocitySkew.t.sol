// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

import "src/interfaces/IChainlinkAggregatorV3.sol";

import "forge-std/console2.sol";

contract OptionsMaxVelocitySkewTest is OrderHelpers, ExpectRevert {
    function setUp() public override {
        super.setUpDefaultWithController({controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);
        controllerModProxy.setMinFundingRate(0); // Minimum funding rate set to 0 as LPs shouldn't pay.

        vaultProxy.setMaxPositionsWhitelist(alice, true);

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

        // With -20% skew, the funding rate velocity should be at maximum (lower bound)
        assertEq(controllerModProxy.currentFundingRate(), 0, "Incorrect funding rate");

        assertEq(
            stableModProxy.stableCollateralPerShare(),
            collateralPerShareBefore,
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

        assertEq(controllerModProxy.currentFundingRate(), 0, "Incorrect funding rate");
    }
}
