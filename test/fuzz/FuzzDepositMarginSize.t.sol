// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Setup} from "../helpers/Setup.sol";
import {OrderHelpers} from "../helpers/OrderHelpers.sol";
import {FuzzHelpers} from "../helpers/FuzzHelpers.sol";
import {IChainlinkAggregatorV3} from "../../src/interfaces/IChainlinkAggregatorV3.sol";

import "forge-std/console2.sol";

contract FuzzDepositMarginSizeTest is Setup, OrderHelpers, FuzzHelpers {
    using Math for uint256;

    function test_fuzz_deposit(uint256 stableDeposit) public {
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        stableDeposit = bound(stableDeposit, keeperFee, 10_000e18); // any lower results in underflow/overflow because the keeper fee is taken from the withdrawal collateral

        uint256 collateralPrice = 1000e8;
        uint256 aliceWethBalanceBefore = WETH.balanceOf(alice);

        vm.startPrank(alice);

        // Deposit stable LP
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 aliceStableBalance = stableModProxy.balanceOf(alice);

        // Withdraw stable LP
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: aliceStableBalance,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            aliceWethBalanceBefore - (keeperFee * 2),
            WETH.balanceOf(alice),
            "Alice didn't receive all the WETH back"
        );
    }

    function test_fuzz_deposit_multiple(uint256 stableDeposit, uint256 stableDeposit2) public {
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        stableDeposit = bound(stableDeposit, keeperFee, 10_000e18);
        stableDeposit2 = bound(stableDeposit, keeperFee, 10_000e18);

        uint256 collateralPrice = 1000e8;
        uint256 aliceWethBalanceBefore = WETH.balanceOf(alice);

        vm.startPrank(alice);

        // Deposit stable LP
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 aliceStableBalance = stableModProxy.balanceOf(alice);

        // Withdraw stable LP
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: aliceStableBalance,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            aliceWethBalanceBefore - (keeperFee * 3),
            WETH.balanceOf(alice),
            "Alice didn't receive all the WETH back"
        );
    }

    function test_fuzz_deposit_with_leverage(uint256 stableDeposit, uint256 priceMultiplier) public {
        uint256 stableLowerBound = (100e18 * 1e18) / vaultProxy.skewFractionMax(); // avoid MaxSkewReached error
        stableDeposit = bound(stableDeposit, stableLowerBound, 10_000e18);
        priceMultiplier = bound(priceMultiplier, 0.8e18, 5e18);

        uint256 margin1 = 10e18;
        uint256 size1 = 30e18;
        uint256 margin2 = 30e18;
        uint256 size2 = 70e18;
        uint256 collateralPrice = 1000e8;

        depositLeverageWithdrawAll(
            DepositLeverageParams(
                alice,
                keeper,
                collateralPrice,
                stableDeposit,
                margin1,
                size1,
                margin2,
                size2,
                priceMultiplier
            )
        );
    }

    function test_fuzz_margin(uint256 margin2, uint256 priceMultiplier) public {
        uint256 margin1 = 10e18;
        uint256 size1 = 30e18;

        // Avoid MaxSkewReached error. Subtract 30e18 to account for the first leverage position. Divide by 2 because size will be 2x margin
        uint256 marginUpperBound = (((100e18 * vaultProxy.skewFractionMax()) / 1e18) - size1) / 2;
        margin2 = bound(margin2, leverageModProxy.marginMin(), marginUpperBound);
        priceMultiplier = bound(priceMultiplier, 0.8e18, 5e18);

        uint256 size2 = margin2 * 2;
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        depositLeverageWithdrawAll(
            DepositLeverageParams(
                alice,
                keeper,
                collateralPrice,
                stableDeposit,
                margin1,
                size1,
                margin2,
                size2,
                priceMultiplier
            )
        );
    }

    function test_fuzz_size(uint256 size2, uint256 priceMultiplier) public {
        uint256 margin1 = 10e18;
        uint256 size1 = 30e18;
        uint256 stableDeposit = 100e18;
        uint256 margin2 = 1e18;
        uint256 collateralPrice = 1000e8;

        size2 = bound(
            size2,
            (margin2 * (leverageModProxy.leverageMin() - 1e18)) / 1e18,
            (margin2 * (leverageModProxy.leverageMax() - 1e18)) / 1e18
        ); // avoid LeverageTooLow/High error
        priceMultiplier = bound(priceMultiplier, 0.98e18, 5e18); // don't trigger liquidation price error

        depositLeverageWithdrawAll(
            DepositLeverageParams(
                alice,
                keeper,
                collateralPrice,
                stableDeposit,
                margin1,
                size1,
                margin2,
                size2,
                priceMultiplier
            )
        );
    }

    function test_fuzz_margin_size(uint256 margin2, uint256 size2, uint256 priceMultiplier) public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 margin1 = 10e18;
        uint256 size1 = 30e18;

        uint256 remainingSize = ((stableDeposit * vaultProxy.skewFractionMax()) / 1e18) - size1;

        priceMultiplier = bound(priceMultiplier, 0.98e18, 5e18); // don't trigger liquidation price error

        margin2 = bound(margin2, leverageModProxy.marginMin(), remainingSize);

        uint256 sizeLowerBound = ((leverageModProxy.leverageMin() * margin2) / 1e18) - margin2 + 1; // avoid LeverageTooLow error, account for rounding error with +1
        uint256 sizeUpperBound = Math.min((margin2 * (leverageModProxy.leverageMax() - 1e18)) / 1e18, remainingSize); // avoid LeverageTooLow/High and MaxSkewReached error

        if (sizeLowerBound < sizeUpperBound) {
            size2 = bound(size2, sizeLowerBound, sizeUpperBound);

            depositLeverageWithdrawAll(
                DepositLeverageParams(
                    alice,
                    keeper,
                    collateralPrice,
                    stableDeposit,
                    margin1,
                    size1,
                    margin2,
                    size2,
                    priceMultiplier
                )
            );
        }
    }

    function test_fuzz_deposit_margin_size_collateral(
        uint256 stableDeposit,
        uint256 margin1,
        uint256 size1,
        uint256 margin2,
        uint256 size2,
        uint256 collateralPrice,
        uint256 priceMultiplier
    ) public {
        vm.startPrank(admin);
        vaultProxy.setMaxFundingVelocity(0.03e18);

        stableDeposit = bound(stableDeposit, 1e18, 10_000e18);
        collateralPrice = bound(collateralPrice, 100e8, 500_000e8); // lower amounts result in PositionCreatesBadDebt error. Would need to increase marginMin to avoid this
        priceMultiplier = bound(priceMultiplier, 0.98e18, 5e18);

        // Leverage position bounds. Fuzzes the margin and size of both positions to system boundaries
        {
            uint256 margin1LowerBound = leverageModProxy.marginMin();
            uint256 margin1UpperBound = margin1LowerBound.max(
                (stableDeposit * (vaultProxy.skewFractionMax() - 1e10)) / (leverageModProxy.leverageMin() - 1e18)
            );

            margin1 = bound(margin1, margin1LowerBound, margin1UpperBound);

            uint256 size1LowerBound = (margin1 * (leverageModProxy.leverageMin() - 1e18)) / 1e18;
            uint256 size1MaxLeverage = (margin1 * (leverageModProxy.leverageMax() - 1e18)) / 1e18;
            uint256 size1UpperBound = size1LowerBound.max(
                size1MaxLeverage.min((stableDeposit * (vaultProxy.skewFractionMax() - 1e10)) / 1e18)
            );

            size1 = bound(size1, size1LowerBound, size1UpperBound);

            uint256 remainingSize = ((stableDeposit * (vaultProxy.skewFractionMax() - 1e10)) / 1e18) - size1;

            // the first position may max out the skewFractionMax, so the second position may not be possible
            if (remainingSize > (leverageModProxy.marginMin() * (leverageModProxy.leverageMin() - 1e18)) / 1e18) {
                uint256 margin2LowerBound = leverageModProxy.marginMin();
                uint256 margin2UpperBound = margin2LowerBound.max(
                    (remainingSize * 1e18) / (leverageModProxy.leverageMin() - 1e18)
                );

                margin2 = bound(margin1, margin2LowerBound, margin2UpperBound);

                uint256 size2LowerBound = (margin2 * (leverageModProxy.leverageMin() - 1e18)) / 1e18;
                uint256 size2MaxLeverage = (margin2 * (leverageModProxy.leverageMax() - 1e18)) / 1e18;
                uint256 size2UpperBound = size2LowerBound.max(size2MaxLeverage.min(remainingSize));

                size2 = bound(size2, size2LowerBound, size2UpperBound);
            } else {
                // the max skew has been reached and cannot open a second position
                margin2 = 0;
                size2 = 0;
            }
        }

        // Leverage can be too low because of rounding error at the limit
        if (margin1 > 0 && (((margin1 + size1) * 1e18) / margin1) < leverageModProxy.leverageMin()) {
            return;
        }
        if (margin2 > 0 && (((margin2 + size2) * 1e18) / margin2) < leverageModProxy.leverageMin()) {
            return;
        }

        setWethPrice(collateralPrice);

        depositLeverageWithdrawAll(
            DepositLeverageParams(
                alice,
                keeper,
                collateralPrice,
                stableDeposit,
                margin1,
                size1,
                margin2,
                size2,
                priceMultiplier
            )
        );
    }
}
