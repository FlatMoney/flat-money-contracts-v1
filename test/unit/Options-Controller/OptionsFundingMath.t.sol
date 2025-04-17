// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "src/interfaces/IChainlinkAggregatorV3.sol";

import "forge-std/console2.sol";

// TODO: Break the this file into multiple files.

contract OptionsFundingMathTest is Setup, OrderHelpers, ExpectRevert {
    function setUp() public override {
        super.setUpDefaultWithController({controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18); // 3% per day

        controllerModProxy.setMinFundingRate(0);

        disableChainlinkExpiry();

        vaultProxy.setMaxPositions(3);
        vaultProxy.setMaxPositionsWhitelist(alice, true);
        vaultProxy.setMaxPositionsWhitelist(bob, true);
    }

    function test_option_pnl_no_price_change_long_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails1 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(30_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails2 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(70_000e18, collateralAsset)
        });
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails1.margin,
            additionalSize: alicePositionDetails1.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails2.margin,
            additionalSize: alicePositionDetails2.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(leverageModProxy.getPositionSummary(tokenId).profitLoss, 0, "PnL for position 1 should be 0");
        assertEq(leverageModProxy.getPositionSummary(tokenId2).profitLoss, 0, "PnL for position 2 should be 0");

        skip(2 days);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // The amount received after closing the positions should be lesser than amount deposited as
        // margin due to losses from funding payments.
        assertLt(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount,
            "Alice's should receive more than her total margin"
        );
    }

    function test_option_pnl_no_price_change_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(200_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails1 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(30_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails2 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(70_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails1.margin,
            additionalSize: alicePositionDetails1.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails2.margin,
            additionalSize: alicePositionDetails2.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(leverageModProxy.getPositionSummary(tokenId).profitLoss, 0, "PnL for position 1 should be 0");
        assertEq(leverageModProxy.getPositionSummary(tokenId2).profitLoss, 0, "PnL for position 2 should be 0");

        skip(2 days);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // The amount received after closing the positions should be greater than amount deposited as
        // collateral due to profit from funding payments.
        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount - (keeperFee * 5),
            "Alice's should receive her margin minus keeper fee"
        );
    }

    function test_pnl_price_increase_long_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails1 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(30_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails2 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(70_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails1.margin,
            additionalSize: alicePositionDetails1.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails2.margin,
            additionalSize: alicePositionDetails2.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // The price of ETH increases by 100%.
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        int256 pnl1 = leverageModProxy.getPositionSummary(tokenId).profitLoss;
        int256 pnl2 = leverageModProxy.getPositionSummary(tokenId2).profitLoss;

        assertEq(pnl1, int256(getQuoteFromDollarAmount(30_000e18, collateralAsset)), "PnL for position 1 is incorrect");
        assertEq(pnl2, int256(getQuoteFromDollarAmount(70_000e18, collateralAsset)), "PnL for position 2 is incorrect");

        skip(2 days);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // The amount received after closing the positions should be lesser than margin deposited + profit from
        // price increase due to losses from funding payments.
        assertLt(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount + uint256(pnl1) + uint256(pnl2),
            "Alice should have profits after closing positions with price increase"
        );
    }

    function test_pnl_price_increase_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(200_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(30_000e18, collateralAsset),
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // The price of ETH increases by 100%.
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();
        int256 pnl1 = leverageModProxy.getPositionSummary(tokenId).profitLoss;
        int256 pnl2 = leverageModProxy.getPositionSummary(tokenId2).profitLoss;

        assertEq(pnl1, int256(getQuoteFromDollarAmount(30_000e18, collateralAsset)), "PnL for position 1 is incorrect");
        assertEq(pnl2, int256(getQuoteFromDollarAmount(70_000e18, collateralAsset)), "PnL for position 2 is incorrect");

        skip(2 days);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // The amount received after closing the positions should be greater than margin deposited + profit from
        // price increase due to profits from funding payments.
        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore -
                aliceDepositDetails.depositAmount +
                uint256(pnl1) +
                uint256(pnl2) -
                (keeperFee * 3 + keeperFee2 * 2),
            "Alice should have profits after closing positions with price increase"
        );
    }

    function test_pnl_price_decrease() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 1000e8,
            keeperFeeAmount: keeperFee
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(30_000e18, collateralAsset),
            oraclePrice: 1000e8,
            keeperFeeAmount: keeperFee
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(70_000e18, collateralAsset),
            oraclePrice: 1000e8,
            keeperFeeAmount: keeperFee
        });

        // The price of ETH decreases by 20%.
        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();
        int256 pnl1 = leverageModProxy.getPositionSummary(tokenId).profitLoss;
        int256 pnl2 = leverageModProxy.getPositionSummary(tokenId2).profitLoss;

        assertEq(pnl1, 0, "PnL for position 1 is incorrect. Call option shouldn't lose anything");
        assertEq(pnl2, 0, "PnL for position 2 is incorrect. Call option shouldn't lose anything");
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            stableCollateralPerShareBefore,
            "Stable collateral per share should be the same after price decrease"
        );

        skip(2 days);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        assertEq(
            uint256(
                int256(aliceBalanceBefore) -
                    int256(aliceDepositDetails.depositAmount) -
                    int256(keeperFee * 3 + keeperFee2 * 2) +
                    pnl1 +
                    pnl2
            ),
            collateralAsset.balanceOf(alice),
            "Alice should have no losses after closing positions with price increase"
        );
    }

    function test_accrued_funding_long_skew_price_increase() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(120_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(120_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount - alicePositionDetails.margin - 2 * keeperFee,
            "Alice's balance incorrect after creating the market"
        ); // 100 deposit to stable LP, 120 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $2k (100% increase)
        setCollateralPrice(2000e8);

        skip(2 days);

        // Leverage traders paid to the stable LPs.
        assertLt(leverageModProxy.getPositionSummary(tokenId).accruedFunding, 0, "Long trader gained funding fees");
        assertLt(
            optionsControllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            viewer.getMarketSummary().profitLossTotalByLongs,
            "Longs gained funding fees"
        );
    }

    function test_accrued_funding_long_skew_price_decrease() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(120_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(120_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount - alicePositionDetails.margin - 2 * keeperFee,
            "Alice's balance incorrect after creating the market"
        ); // 100 deposit to stable LP, 120 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $800 (20% decrease)
        setCollateralPrice(800e8);

        skip(2 days);

        // Leverage traders paid to the stable LPs.
        assertLt(leverageModProxy.getPositionSummary(tokenId).accruedFunding, 0, "Long trader gained funding fees");
        assertLt(
            optionsControllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            viewer.getMarketSummary().profitLossTotalByLongs,
            "Longs gained funding fees"
        );
    }

    function test_accrued_funding_stable_skew_price_increase() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(40_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(40_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 40 ETH collateral, 40 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - alicePositionDetails.margin - aliceDepositDetails.depositAmount - 2 * keeperFee,
            "Alice's balance incorrect"
        ); // 100 deposit to stable LP, 40 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $2k (100% increase)
        setCollateralPrice(2000e8);

        skip(2 days);

        assertEq(
            leverageModProxy.getPositionSummary(tokenId).accruedFunding,
            0,
            "Long trader should gain no funding fees because of no negative funding"
        );
        assertEq(
            optionsControllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            viewer.getMarketSummary().profitLossTotalByLongs,
            "Longs should gain no funding fees because of no negative funding"
        );
    }

    function test_accrued_funding_stable_skew_price_decrease() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(40_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(40_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 40 ETH collateral, 40 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - alicePositionDetails.margin - aliceDepositDetails.depositAmount - 2 * keeperFee,
            "Alice's balance incorrect"
        ); // 100 deposit to stable LP, 40 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $800 (20% decrease)
        setCollateralPrice(800e8);

        skip(2 days);

        assertEq(
            leverageModProxy.getPositionSummary(tokenId).accruedFunding,
            0,
            "Short trader should gain no funding fees because of no negative funding"
        );
        assertEq(
            optionsControllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            viewer.getMarketSummary().profitLossTotalByLongs,
            "Shorts should gain no funding fees because of no negative funding"
        );
    }

    function test_accrued_funding_long_then_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(120_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(120_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount - alicePositionDetails.margin - 2 * keeperFee,
            "Alice's balance incorrect after creating the market"
        ); // 100 deposit to stable LP, 120 deposit into 1 leveraged position

        skip(1 days);

        int256 currentFundingRate = optionsControllerModProxy.currentFundingRate();

        vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());
        int256 fundingRateAfterExecution = optionsControllerModProxy.currentFundingRate();
        vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());

        // Leverage traders paid to the stable LPs.
        assertEq(currentFundingRate, 0.03e18, "Funding rate should be positive");
        assertLt(leverageModProxy.getPositionSummary(tokenId).accruedFunding, 0, "Long trader has to pay funding fees");
        assertLt(
            optionsControllerModProxy.fundingAdjustedLongPnLTotal({maxAge_: type(uint32).max, priceDiffCheck_: false}),
            viewer.getMarketSummary().profitLossTotalByLongs,
            "Longs have to pay funding fees"
        );

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0e18,
            additionalSizeAdjustment: -40e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee2
        });

        currentFundingRate = optionsControllerModProxy.currentFundingRate();
        assertEq(currentFundingRate, fundingRateAfterExecution, "Funding rate should be positive");

        skip(2 days);

        currentFundingRate = optionsControllerModProxy.currentFundingRate();
        assertEq(currentFundingRate, 0, "Funding rate should stil be 0");

        optionsControllerModProxy.settleFundingFees();

        currentFundingRate = optionsControllerModProxy.currentFundingRate();
        assertEq(currentFundingRate, 0, "Funding rate should not change after settlement");
    }

    function test_accounting_accrued_fees_for_stable_shares_long_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(120_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(120_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 aliceLiquidityMinted = stableModProxy.balanceOf(alice);

        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - aliceDepositDetails.depositAmount - alicePositionDetails.margin - 2 * keeperFee,
            "Alice's balance incorrect after creating the market"
        ); // 100 deposit to stable LP, 120 deposit into 1 leveraged position

        skip(2 days);

        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Same amount as Alice
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 bobLiquidityMinted = stableModProxy.balanceOf(bob);

        // Since the market was skewed towards the long side, the stable LPs should have gained funding fees.
        // This means `stableCollaterPerShare` should be higher compared to the time Alice minted liquidity.
        // Since liquidity minted is inversely proportional to `stableCollateralPerShare`, Alice should have minted more liquidity than Bob.
        assertGt(aliceLiquidityMinted, bobLiquidityMinted, "Alice's liquidity minted should be greater than Bob's");
    }

    function test_accounting_accrued_fees_for_stable_shares_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(40_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(40_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 aliceLiquidityMinted = stableModProxy.balanceOf(alice);

        // 40 ETH collateral, 40 ETH additional size (2x leverage)
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - alicePositionDetails.margin - aliceDepositDetails.depositAmount - 2 * keeperFee,
            "Alice's balance incorrect"
        ); // 100 deposit to stable LP, 40 deposit into 1 leveraged position

        skip(2 days);

        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Same amount as Alice
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 bobLiquidityMinted = stableModProxy.balanceOf(bob);
        int256 currentFunding = optionsControllerModProxy.currentFundingRate();

        // Since the market was skewed towards the short side, the stable LPs should have lost funding fees.
        // This means `stableCollaterPerShare` should be lower compared to the time Alice minted liquidity.
        // Since liquidity minted is inversely proportional to `stableCollateralPerShare`, Alice should have minted less liquidity than Bob.
        assertEq(
            aliceLiquidityMinted,
            bobLiquidityMinted,
            "Alice's liquidity minted should be same as Bob's because no negative funding"
        );
        assertEq(currentFunding, 0, "Funding rate should be 0");
    }

    // TODO: Revisit the test assertions.
    function test_current_funding_rate_when_market_prefectly_hedged() public {
        uint256 collateralPrice = 1000e8;

        // Creating a leverage position with leverage ratio 3x.
        // Note that this function creates a delta neutral position.
        announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            margin: getQuoteFromDollarAmount(50_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        int256 currentFundingRateBefore = optionsControllerModProxy.currentFundingRate();

        // The price of ETH increases by 100%.
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        skip(2 days);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: getQuoteFromDollarAmount(1e18, collateralAsset),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // The recomputed funding rate shouldn't be too different from the funding rate before the latest stable deposit.
        // We don't want big jumps happening due to small deposits.
        assertApproxEqAbs(
            optionsControllerModProxy.currentFundingRate(),
            currentFundingRateBefore,
            1e6,
            "Funding rate shouldn't change"
        );
    }

    // This test does the following:
    // 1. Opens a hedged LP and leverage position with no skew
    // 2. Opens an additional leverage position to create positive skew (funding rates activated)
    // 3. Skips 1 day
    // 4. Checks accrued funding rate matches current funding rate
    // 5. Closes all positions and checks balances
    function test_funding_accrued() public {
        // Set funding velocity to 0 so that the funding rate is not affected in the beginning
        // this means that the funding will be 0 and skew will be 0 for the initial perfect hedge
        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0);
        // Disable trading fees so that they don't impact the tests
        FeeManager(address(vaultProxy)).setStableWithdrawFee(0);
        FeeManager(address(vaultProxy)).setLeverageTradingFee(0);

        vm.startPrank(alice);

        setCollateralPrice(2000e8);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 initialStableCollateralPerShare = stableModProxy.stableCollateralPerShare();
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        uint256 tokenId1 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        // Skew = 0
        LeverageModuleStructs.PositionSummary memory positionSummary = leverageModProxy.getPositionSummary(tokenId1);
        FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();
        assertEq(vaultSummary.marketSkew, 0, "Market skew should be 0");
        assertEq(optionsControllerModProxy.currentFundingRate(), 0, "Initial funding rate should be 0");
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            initialStableCollateralPerShare,
            "Initial stable collateral per share should be $1"
        );
        assertEq(positionSummary.accruedFunding, 0, "Initial position accrued funding should be 0");
        assertEq(positionSummary.profitLoss, 0, "Initial position profit loss should be 0");
        assertEq(
            positionSummary.marginAfterSettlement,
            int256(alicePositionDetails.margin),
            "Initial position margin after settlement should be 100e18"
        );

        skip(1 days);

        // Nothing should change because skew = 0
        positionSummary = leverageModProxy.getPositionSummary(tokenId1);
        vaultSummary = viewer.getVaultSummary();
        assertEq(vaultSummary.marketSkew, 0, "Market skew should be 0");
        assertEq(optionsControllerModProxy.currentFundingRate(), 0, "Funding rate should be 0 after 1 day");
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            initialStableCollateralPerShare,
            "Stable collateral per share shouldn't change after 1 day"
        );
        assertEq(positionSummary.accruedFunding, 0, "Initial position accrued funding should be 0 after 1 day");
        assertEq(positionSummary.profitLoss, 0, "Initial position profit loss should be 0 after 1 day");
        assertEq(
            positionSummary.marginAfterSettlement,
            int256(alicePositionDetails.margin),
            "Initial position margin after settlement should be 100e18 after 1 day"
        );

        // now that the system is perfectly hedged, let's check the funding math
        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0.003e18); // 0.3% per day

        InitialPositionDetails memory alicePositionDetails2 = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(10_000e18, collateralAsset)
        });

        // Skew towards longs 10%
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails2.margin,
            additionalSize: alicePositionDetails2.additionalSize,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            optionsControllerModProxy.currentFundingRate(),
            0,
            "Incorrect funding rate immediately after skew change"
        );
        vaultSummary = viewer.getVaultSummary();
        assertEq(
            vaultSummary.marketSkew,
            int256(getQuoteFromDollarAmount(10_000e18, collateralAsset)),
            "Market skew should be 10e18 immediately after skew change"
        );

        skip(1 days);
        vaultSummary = viewer.getVaultSummary();
        assertEq(
            vaultSummary.marketSkew,
            int256(getQuoteFromDollarAmount(10_000e18, collateralAsset)),
            "Market skew should be 10e18 after 1 day skew"
        );
        assertEq(optionsControllerModProxy.currentFundingRate(), 0.003e18, "Incorrect funding rate after 1 day skew");
        positionSummary = leverageModProxy.getPositionSummary(tokenId2);
        assertEq(
            ((positionSummary.accruedFunding * -1) * int256(10 ** collateralAsset.decimals())) /
                int256(alicePositionDetails2.additionalSize), // divide by the size
            optionsControllerModProxy.currentFundingRate() / 2,
            "Incorrect accrued funding after 1 day skew"
        );
        uint256 traderCollateralBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 expectedReceivedAmount;
        {
            vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());

            int256 accruedFunding = leverageModProxy.getPositionSummary(tokenId2).accruedFunding;
            expectedReceivedAmount = uint256(int256(alicePositionDetails2.margin) + accruedFunding - int256(keeperFee));

            vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());
        }

        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            traderCollateralBalanceBefore + expectedReceivedAmount,
            1e7, // This is an unusual case where we need to use a higher tolerance
            "Trader didn't get correct amount of collateralAsset after close"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId1,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - 6 * keeperFee,
            1e6,
            "Trader didn't get all her collateralAsset back after closing everything"
        );
    }

    function test_funding_rate_unaffected_by_market_size() public {
        // The funding rate should only be affected by the skew, not total collateral market size
        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0);
        // Disable trading fees so that they don't impact the tests
        FeeManager(address(vaultProxy)).setStableWithdrawFee(0);
        FeeManager(address(vaultProxy)).setLeverageTradingFee(0);

        vm.startPrank(alice);

        setCollateralPrice(2000e8);

        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset)
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(110_000e18, collateralAsset)
        });

        uint256 snapshot = vm.snapshotState();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0.003e18); // 0.3% per day

        skip(1 days);

        FlatcoinVaultStructs.VaultSummary memory vaultSummary = viewer.getVaultSummary();
        assertEq(
            vaultSummary.marketSkew,
            int256(getQuoteFromDollarAmount(10_000e18, collateralAsset)),
            "Market should be skewed 10% long (initial market size)"
        );
        assertEq(
            optionsControllerModProxy.currentFundingRate(),
            0.003e18,
            "Incorrect funding rate (initial market size)"
        ); // 0.3% with 10% skew

        vm.revertToState(snapshot);

        aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(1_000_000e18, collateralAsset)
        });
        alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_100_000e18, collateralAsset)
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: alicePositionDetails.margin,
            additionalSize: alicePositionDetails.additionalSize,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0.003e18);

        // minimum delay to keep the accrued funding close to being round and clean
        orderAnnouncementModProxy.setMinExecutabilityAge(1);
        orderExecutionModProxy.setMaxExecutabilityAge(60);

        vm.startPrank(alice);

        skip(1 days);

        vaultSummary = viewer.getVaultSummary();
        assertEq(
            vaultSummary.marketSkew,
            int256(getQuoteFromDollarAmount(100_000e18, collateralAsset)),
            "Market should be skewed 10% long (bigger market size)"
        );
        assertEq(
            optionsControllerModProxy.currentFundingRate(),
            0.003e18,
            "Incorrect funding rate (bigger market size)"
        );

        uint256 aliceCollateralBefore = collateralAsset.balanceOf(alice);

        skip(1 days);

        int256 expectedFundingRate;
        uint256 expectedReceivedAmount;
        {
            vm.warp(block.timestamp + orderAnnouncementModProxy.minExecutabilityAge());

            expectedFundingRate = controllerModProxy.currentFundingRate();
            int256 accruedFunding = leverageModProxy.getPositionSummary(tokenId).accruedFunding;
            expectedReceivedAmount = uint256(int256(alicePositionDetails.margin) + accruedFunding - int256(keeperFee));

            vm.warp(block.timestamp - orderAnnouncementModProxy.minExecutabilityAge());
        }

        // We can close the position to make sure nothing funny is going on with the funding rate
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        uint256 aliceCollateralReceived = collateralAsset.balanceOf(alice) - aliceCollateralBefore;

        assertEq(
            vaultSummary.marketSkew,
            int256(getQuoteFromDollarAmount(100_000e18, collateralAsset)),
            "Market should be skewed 10% long (bigger market size)"
        );

        // The error tolerance is this high because after announcement of the last order, settlement of funding fees
        // causes the skew to reduce and thus the funding velocity to reduce which impacts the funding rate between
        // the announcement and execution of the last order. However, it's a very small amount and complicating this assertion
        // serves no useful purpose.
        assertApproxEqAbs(
            optionsControllerModProxy.currentFundingRate(),
            0.006e18,
            1e11,
            "Incorrect funding rate (bigger market size)"
        );
        assertApproxEqAbs(
            aliceCollateralReceived,
            expectedReceivedAmount,
            1e7,
            "Alice's collateralAsset received is incorrect"
        );
    }

    // TODO: Change this test to use more assertions or else move it to a different test file.
    function test_funding_rate_skew_change() public {
        // The funding rate should only be affected by the skew, not total collateral market size
        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0);
        // Disable trading fees so that they don't impact the tests
        FeeManager(address(vaultProxy)).setStableWithdrawFee(0);
        FeeManager(address(vaultProxy)).setLeverageTradingFee(0);

        vm.startPrank(alice);

        setCollateralPrice(2000e8);

        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(100_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(120_000e18, collateralAsset),
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0.003e18); // 0.3% per day

        int256 currentSkewBefore = optionsControllerModProxy.getCurrentSkew();
        int256 skewBefore = viewer.getVaultSummary().marketSkew;
        int256 skewPercentageBefore = viewer.getMarketSkewPercentage();

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceOpenLeverage.selector,
                alice,
                getQuoteFromDollarAmount(100e18, collateralAsset),
                getQuoteFromDollarAmount(100e18, collateralAsset),
                0
            ),
            expectedErrorSignature: "MaxSkewReached(uint256)",
            ignoreErrorArguments: true
        });

        assertEq(currentSkewBefore, skewBefore, "Current skew should be equal to market skew");

        skip(1 days);

        // Should be able to open a position because funding closes the skew
        {
            uint256 snapshot = vm.snapshotState();
            announceOpenLeverage({
                traderAccount: alice,
                margin: getQuoteFromDollarAmount(100e18, collateralAsset),
                additionalSize: getQuoteFromDollarAmount(100e18, collateralAsset),
                keeperFeeAmount: 0
            });
            vm.revertToState(snapshot);
        }

        int256 currentSkewAfter = optionsControllerModProxy.getCurrentSkew();
        int256 skewAfter = viewer.getVaultSummary().marketSkew;
        int256 skewPercentageAfter = viewer.getMarketSkewPercentage();

        assertLt(currentSkewAfter, currentSkewBefore, "Current skew should decrease over time");
        assertLt(skewPercentageAfter, skewPercentageBefore, "Skew percentage should decrease over time");
        assertLt(currentSkewAfter, skewAfter, "Current skew should be lower than market skew over time");

        optionsControllerModProxy.settleFundingFees();

        assertApproxEqAbs(
            currentSkewAfter,
            viewer.getVaultSummary().marketSkew,
            1, // account for rounding adjustment
            "Market skew should be updated after settlement"
        );
    }

    // Test that the system handles accounting properly in case the global margin deposited
    // is depleted due to funding payments to LPs.
    // The system should be able to resume when the positions which are underwater are liquidated.
    // Meaning, when all positions are liquidated the LPs should be able to redeem their shares.
    function test_accounting_global_margin_depleted_due_to_funding() public {
        setCollateralPrice(1000e8);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: getQuoteFromDollarAmount(23_000e18, collateralAsset),
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(24_000e18, collateralAsset),
            oraclePrice: 1000e8,
            keeperFeeAmount: keeperFee
        });

        vm.startPrank(admin);
        optionsControllerModProxy.setMaxFundingVelocity(0.006e18);
        optionsControllerModProxy.setMaxVelocitySkew(0.2e18);

        // Note that the amount of days to be skipped has been chosen arbitrarily.
        skip(15 days);

        optionsControllerModProxy.settleFundingFees();

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        int256 globalMargin = vaultProxy.getGlobalPositions().marginDepositedTotal;

        assertEq(
            globalMargin + int256(stableCollateralTotal),
            int256(collateralAsset.balanceOf(address(vaultProxy))),
            "Sum of global margin and stable collateral should be equal to the total collateralAsset balance of the vault"
        );

        // Liquidate the bad position to enable full withdrawal of stable collateral.
        // This should correctly reverse the funding fee payments to the LPs.
        setCollateralPrice(1000e8); // `liquidate` needs a price within the last 24h
        vm.startPrank(liquidator);
        liquidationModProxy.liquidate(tokenId);

        // Let's try to redeem all the stable collateral from the vault.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            5000, // rounding from oracle price calculations likely
            "Vault should have no collateralAsset balance after withdrawal"
        );
        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore + getQuoteFromDollarAmount(1_000e18, collateralAsset) - (keeperFee * 2) - 5000,
            "Alice should have received all her collateralAsset + margin of Bob's position"
        );
    }
}
