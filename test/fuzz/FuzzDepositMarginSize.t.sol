// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {Setup} from "../helpers/Setup.sol";
import {OrderHelpers} from "../helpers/OrderHelpers.sol";
import {FuzzHelpers} from "../helpers/FuzzHelpers.sol";
import {IChainlinkAggregatorV3} from "../../src/interfaces/IChainlinkAggregatorV3.sol";

import {MockERC20} from "../mocks/MockERC20.sol";

import "forge-std/console2.sol";

abstract contract FuzzDepositMarginSizeBase is OrderHelpers, FuzzHelpers {
    using Math for uint256;

    function test_fuzz_deposit(uint256 stableDeposit) public {
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 collateralPrice = 1000e8;
        uint256 minDepositAmount = getQuoteFromDollarAmount(
            orderAnnouncementModProxy.minDepositAmountUSD(),
            collateralAsset
        );

        uint256 aliceWethBalanceBefore = collateralAsset.balanceOf(alice);

        stableDeposit = bound(stableDeposit, minDepositAmount, (10_000 * 10 ** collateralAsset.decimals())); // any lower results in underflow/overflow because the keeper fee is taken from the withdrawal collateral

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

        assertApproxEqAbs(
            aliceWethBalanceBefore - (keeperFee * 2),
            collateralAsset.balanceOf(alice),
            collateralAsset.balanceOf(alice) / 1e15 + 1, // some rounding is ok
            "Alice didn't receive all the collateralAsset back"
        );
    }

    function test_fuzz_deposit_multiple(uint256 stableDeposit, uint256 stableDeposit2) public {
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 collateralPrice = 1000e8;
        uint256 minDepositAmount = getQuoteFromDollarAmount(
            orderAnnouncementModProxy.minDepositAmountUSD(),
            collateralAsset
        );

        stableDeposit = bound(stableDeposit, minDepositAmount, (10_000 * 10 ** collateralAsset.decimals()));
        stableDeposit2 = bound(stableDeposit2, minDepositAmount, (10_000 * 10 ** collateralAsset.decimals()));

        uint256 aliceWethBalanceBefore = collateralAsset.balanceOf(alice);

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

        assertApproxEqAbs(
            aliceWethBalanceBefore - (keeperFee * 3),
            collateralAsset.balanceOf(alice),
            collateralAsset.balanceOf(alice) / 1e15 + 1, // some rounding is ok
            "Alice didn't receive all the collateralAsset back"
        );
    }

    function test_fuzz_deposit_with_leverage(uint256 stableDeposit, uint256 priceMultiplier) public {
        uint256 collateralPrice = 1000e8;
        uint256 decimals = collateralAsset.decimals();

        // The total size in this test is 100 units, and the stable lower bound is based on it.
        uint256 stableLowerBound = (100 * (10 ** decimals) * 1e18) / vaultProxy.skewFractionMax() + 1; // avoid MaxSkewReached error
        uint256 minDepositAmount = getQuoteFromDollarAmount(
            orderAnnouncementModProxy.minDepositAmountUSD(),
            collateralAsset
        );

        stableDeposit = bound(
            stableDeposit,
            stableLowerBound > minDepositAmount ? stableLowerBound : minDepositAmount,
            10_000 * (10 ** decimals)
        );
        priceMultiplier = bound(priceMultiplier, 0.8e18, 5e18); // change in collateral price before closing positions

        uint256 margin1 = 10 * (10 ** decimals);
        uint256 size1 = 30 * (10 ** decimals);
        uint256 margin2 = 30 * (10 ** decimals);
        uint256 size2 = 70 * (10 ** decimals);

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
        uint256 collateralPrice = 1000e8;
        uint256 decimals = collateralAsset.decimals();

        uint256 stableDeposit = 100 * (10 ** decimals);
        uint256 margin1 = 10 * (10 ** decimals);
        uint256 size1 = 30 * (10 ** decimals);

        // Avoid MaxSkewReached error. Subtract 30e18 to account for the first leverage position. Divide by 2 because size will be 2x margin
        uint256 marginUpperBound = ((((100 * (10 ** decimals)) * vaultProxy.skewFractionMax()) / 1e18) - size1) / 2;
        margin2 = bound(margin2, leverageModProxy.marginMin(), marginUpperBound);
        priceMultiplier = bound(priceMultiplier, 0.8e18, 5e18); // change in price before closing positions

        uint256 size2 = margin2 * 2 - 1;

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
        uint256 collateralPrice = 1000e8;
        uint256 decimals = collateralAsset.decimals();

        uint256 stableDeposit = 100 * (10 ** decimals);
        uint256 margin1 = 10 * (10 ** decimals);
        uint256 size1 = 30 * (10 ** decimals);
        uint256 margin2 = 1 * (10 ** decimals);

        size2 = bound(
            size2,
            (margin2 * (leverageModProxy.leverageMin() - 1e18)) / 1e18,
            (margin2 * (leverageModProxy.leverageMax() - 1e18)) / 1e18
        ); // avoid LeverageTooLow/High error
        priceMultiplier = bound(priceMultiplier, 0.98e18, 5e18); // change in price before closing positions. Don't trigger liquidation price error

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
        uint256 collateralPrice = 1000e8;
        uint256 decimals = collateralAsset.decimals();

        uint256 stableDeposit = 100 * (10 ** decimals);
        uint256 margin1 = 10 * (10 ** decimals);
        uint256 size1 = 30 * (10 ** decimals);

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
        controllerModProxy.setMaxFundingVelocity(0.03e18);

        collateralPrice = bound(collateralPrice, 100e8, 500_000e8); // lower amounts result in PositionCreatesBadDebt error. Would need to increase marginMin to avoid this
        {
            uint256 decimals = collateralAsset.decimals();

            stableDeposit = bound(
                stableDeposit,
                1 * (10 ** decimals), // loose minimum, was tested before
                10_000 * (10 ** decimals)
            );
        }
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

        setCollateralPrice(collateralPrice);

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

/// @dev Test contract with collateral asset having less than 18 decimals.
contract FuzzDepositMarginSizeTestLessThan18DecimalsCollateral is FuzzDepositMarginSizeBase {
    function setUp() public override {
        vm.startPrank(admin);

        // Creating collateralAsset as the market asset and USDC as the collateral asset.
        collateralAsset = new MockERC20();

        collateralAsset.initialize("Wrapped Bitcoin", "WBTC", 8);

        vm.label(address(collateralAsset), "WBTC");

        super.setUpWithController({collateral_: collateralAsset, controller_: Setup.ControllerType.PERP});

        vm.startPrank(admin);

        leverageModProxy.setLeverageCriteria({
            marginMin_: getQuoteFromDollarAmount(50e18, collateralAsset), // $50 in collateral terms
            leverageMin_: leverageModProxy.leverageMin(),
            leverageMax_: leverageModProxy.leverageMax()
        });
    }
}

/// @dev Test contract with collateral asset having exactly 18 decimals.
contract FuzzDepositMarginSizeTestEqualTo18DecimalsCollateral is FuzzDepositMarginSizeBase {
    function setUp() public override {
        super.setUpDefaultWithController({controller_: Setup.ControllerType.PERP});
    }
}

/// @dev Test contract with collateral asset having greater than 18 decimals.
contract FuzzDepositMarginSizeTestGreaterThan18DecimalsCollateral is FuzzDepositMarginSizeBase {
    function setUp() public override {
        vm.startPrank(admin);

        // Creating collateralAsset as the market asset and USDC as the collateral asset.
        collateralAsset = new MockERC20();

        collateralAsset.initialize("Bonkers", "BONK", 22);

        vm.label(address(collateralAsset), "BONK");

        super.setUpWithController({collateral_: collateralAsset, controller_: Setup.ControllerType.PERP});

        vm.startPrank(admin);

        leverageModProxy.setLeverageCriteria({
            marginMin_: getQuoteFromDollarAmount(50e18, collateralAsset), // $50 in collateral terms
            leverageMin_: leverageModProxy.leverageMin(),
            leverageMax_: leverageModProxy.leverageMax()
        });
    }
}
