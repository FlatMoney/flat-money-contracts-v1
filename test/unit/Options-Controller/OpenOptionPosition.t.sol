// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "forge-std/console2.sol";

abstract contract OpenOptionPositionConstantCollateralPriceTestsBase is Setup, OrderHelpers, ExpectRevert {
    struct PositionState {
        LeverageModuleStructs.Position position;
        LeverageModuleStructs.PositionSummary positionSummary;
    }

    uint256 initialCollateralAssetPrice;
    uint256 initialStableCollateralPerShare;

    /// @notice This tests correct LP accounting with a position in profit and a position out of profit.
    function test_option_2_positions_in_and_out_of_profit() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(20_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(10_000e18, collateralAsset)
        });

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(10_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(10_000e18, collateralAsset)
        });

        setCollateralPrice(1000e8);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        initialStableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(1300e8);

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize,
            oraclePrice: 1300e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(1300e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        PositionState memory positionStateCarol = PositionState({
            position: vaultProxy.getPosition(tokenIdCarol),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdCarol)
        });

        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            positionStateBob.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(3_000e18, collateralAsset)),
            "Bob PnL should be $3k"
        );
        assertEq(positionStateCarol.positionSummary.profitLoss, 0, "Carol PnL should be 0");
        assertEq(
            positionStateCarol.positionSummary.marginAfterSettlement,
            int256(carolPositionDetails.margin),
            "Carol margin should be the same"
        );
        assertApproxEqRel(
            stableCollateralPerShare,
            ((initialStableCollateralPerShare * 1000) / (1300 * 2)) + (initialStableCollateralPerShare / 2),
            0.0001e18, // 0.01%
            "Stable collateral per share should take into account both positions"
        );
        assertEq(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss + positionStateCarol.positionSummary.profitLoss,
            "Global market profit and loss total incorrect"
        );

        // Close all positions without issue
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1300e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdCarol,
            traderAccount: carol,
            keeperAccount: keeper,
            oraclePrice: 1300e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 1300e8,
            keeperFeeAmount: 0
        });
    }

    function test_option_price_decrease_no_skew() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(10_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(750e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            stableCollateralPerShare,
            initialStableCollateralPerShare,
            "Stable collateral per share shouldn't change"
        );
        assertEq(positionStateBob.positionSummary.profitLoss, 0, "Bob PnL should be 0");
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin),
            "Bob margin should be the same"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_option_price_increase_lp_skew() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(5_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(2000e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            positionStateBob.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(5_000e18, collateralAsset)),
            "Bob PnL is wrong"
        );
        assertEq(
            stableCollateralPerShare,
            (initialStableCollateralPerShare *
                (aliceDepositDetails.depositAmount - getQuoteFromDollarAmount(5_000e18, collateralAsset))) /
                aliceDepositDetails.depositAmount,
            "Stable collateral per share should be half the original value"
        );
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin + getQuoteFromDollarAmount(5_000e18, collateralAsset)),
            "Bob margin should increase with profit"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_option_price_increase_long_skew() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(11_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(1100e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            positionStateBob.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(1_100e18, collateralAsset)),
            "Bob PnL is wrong"
        );
        assertEq(
            stableCollateralPerShare,
            (initialStableCollateralPerShare *
                (aliceDepositDetails.depositAmount - getQuoteFromDollarAmount(1_100e18, collateralAsset))) /
                aliceDepositDetails.depositAmount,
            "Stable collateral per share should be less than the original value"
        );
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin + getQuoteFromDollarAmount(1_100e18, collateralAsset)),
            "Bob margin should increase with profit"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_option_price_decrease_long_skew() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(11_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(900e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        // The original stableCollateralPerShare value is 1e6.
        assertEq(
            stableCollateralPerShare,
            initialStableCollateralPerShare,
            "Stable collateral per share shouldn't change"
        );
        assertEq(positionStateBob.positionSummary.profitLoss, 0, "Bob PnL is wrong");
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin),
            "Bob margin shouldn't change"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_option_multiple_price_decrease() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(5_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(750e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            stableCollateralPerShare,
            initialStableCollateralPerShare,
            "Stable collateral per share shouldn't change"
        );
        assertEq(positionStateBob.positionSummary.profitLoss, int256(0), "Bob PnL should be 0");
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin),
            "Bob margin should be the same as before"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(3_750e18, collateralAsset) // Equivalent to 5 units of market asset
        });

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize, // Equivalent to 5 units of market asset
            oraclePrice: 750e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(500e8);

        stableCollateralTotal = vaultProxy.stableCollateralTotal();
        stableCollateralPerShare = stableModProxy.stableCollateralPerShare();
        positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });
        PositionState memory positionStateCarol = PositionState({
            position: vaultProxy.getPosition(tokenIdCarol),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdCarol)
        });

        assertEq(
            stableCollateralPerShare,
            initialStableCollateralPerShare,
            "Stable collateral per share shouldn't change"
        );
        assertEq(positionStateBob.positionSummary.profitLoss, int256(0), "Bob PnL should be 0");
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin),
            "Bob margin shouldn't change"
        );
        assertEq(positionStateCarol.positionSummary.profitLoss, int256(0), "Carol PnL should be 0");
        assertEq(
            positionStateCarol.positionSummary.marginAfterSettlement,
            int256(carolPositionDetails.margin),
            "Carol margin shouldn't change"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total shouldn't change"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            0,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_option_multiple_price_increase() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(5_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the market asset ($1000 in this case)
            keeperFeeAmount: 0
        });

        setCollateralPrice(1500e8);

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            positionStateBob.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(2_500e18, collateralAsset)),
            "Bob PnL should be $2500"
        );
        assertEq(
            stableCollateralPerShare,
            (initialStableCollateralPerShare *
                (aliceDepositDetails.depositAmount - getQuoteFromDollarAmount(2_500e18, collateralAsset))) /
                aliceDepositDetails.depositAmount,
            "Stable collateral per share should decrease"
        );
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin + getQuoteFromDollarAmount(2_500e18, collateralAsset)),
            "Bob margin should increase with profit"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total should remain same"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(4_500e18, collateralAsset) // Equivalent to 3 units of market asset
        });

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize, // Equivalent to 3 units of market asset
            oraclePrice: 1500e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(2000e8);

        stableCollateralTotal = vaultProxy.stableCollateralTotal();
        stableCollateralPerShare = stableModProxy.stableCollateralPerShare();
        positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });
        PositionState memory positionStateCarol = PositionState({
            position: vaultProxy.getPosition(tokenIdCarol),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdCarol)
        });

        assertEq(
            positionStateBob.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(5_000e18, collateralAsset)),
            "Bob PnL should be $5000"
        );
        assertEq(
            positionStateCarol.positionSummary.profitLoss,
            int256(getQuoteFromDollarAmount(1_500e18, collateralAsset)),
            "Carol PnL should be $1500"
        );
        // Since the PnL of Bob and Carol combined is $6500, the stable collateral per share
        // should decrease by 65%.
        assertEq(
            stableCollateralPerShare,
            (initialStableCollateralPerShare *
                (aliceDepositDetails.depositAmount -
                    (getQuoteFromDollarAmount(5_000e18, collateralAsset) +
                        getQuoteFromDollarAmount(1_500e18, collateralAsset)))) / aliceDepositDetails.depositAmount,
            "Stable collateral per share should decrease"
        );
        assertEq(
            positionStateBob.positionSummary.marginAfterSettlement,
            int256(bobPositionDetails.margin + getQuoteFromDollarAmount(5_000e18, collateralAsset)),
            "Bob margin should be $10000"
        );
        assertEq(
            positionStateCarol.positionSummary.marginAfterSettlement,
            int256(carolPositionDetails.margin + getQuoteFromDollarAmount(1_500e18, collateralAsset)),
            "Carol margin should be $6500"
        );
        assertEq(
            int256(stableCollateralTotal),
            int256(aliceDepositDetails.depositAmount),
            "Stable collateral total should remain same"
        );

        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateBob.positionSummary.profitLoss + positionStateCarol.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
    }

    function test_revert_open_option_position_unauthorized_caller() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory alicePositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(5_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(5_000e18, collateralAsset)
        });

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount, // Deposit $10_000 worth of collateral
            oraclePrice: initialCollateralAssetPrice, // Oracle price of the collateral asset ($1 in this case)
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceOpenLeverage.selector,
                alice,
                alicePositionDetails.margin,
                alicePositionDetails.additionalSize,
                0
            ),
            expectedErrorSignature: "UnauthorizedReceiver(address)",
            errorData: abi.encodeWithSelector(OrderAnnouncementModule.UnauthorizedReceiver.selector, alice)
        });
    }
}

// NOTE: All the `OpenOptionPositionTest` contracts assume the market asset is 18 decimals.
// However, the tests are written in a way that the market asset can have any number of decimals.

/// @dev Test contract for OpenOptionPositionTest with collateral asset having less than 18 decimals.
contract OpenOptionPositionTestLessThan18DecimalsCollateral is OpenOptionPositionConstantCollateralPriceTestsBase {
    function setUp() public override {
        vm.startPrank(admin);

        // Creating collateralAsset as the market asset and USDC as the collateral asset.
        collateralAsset = new MockERC20();

        collateralAsset.initialize("Wrapped Bitcoin", "WBTC", 8);

        vm.label(address(collateralAsset), "WBTC");

        initialCollateralAssetPrice = 1000e8; // $1000

        super.setUpWithController({collateral_: collateralAsset, controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);

        leverageModProxy.setLeverageCriteria({
            marginMin_: getQuoteFromDollarAmount(50e18, collateralAsset), // $50 in collateral terms
            leverageMin_: leverageModProxy.leverageMin(),
            leverageMax_: leverageModProxy.leverageMax()
        });

        setCollateralPrice(initialCollateralAssetPrice);

        vaultProxy.setMaxPositions(3);
        vaultProxy.setMaxPositionsWhitelist(bob, true);
        vaultProxy.setMaxPositionsWhitelist(carol, true);

        initialStableCollateralPerShare = 1e36 / (initialCollateralAssetPrice * 1e10);
    }
}

contract OpenOptionPositionTestEqualTo18DecimalsCollateral is OpenOptionPositionConstantCollateralPriceTestsBase {
    function setUp() public override {
        initialCollateralAssetPrice = 1000e8; // $1000

        super.setUpDefaultWithController({controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);

        setCollateralPrice(initialCollateralAssetPrice);

        vaultProxy.setMaxPositions(3);
        vaultProxy.setMaxPositionsWhitelist(bob, true);
        vaultProxy.setMaxPositionsWhitelist(carol, true);

        initialStableCollateralPerShare = 1e36 / (initialCollateralAssetPrice * 1e10);
    }
}

/// @dev Test contract for OpenOptionPositionTest with collateral asset having greater than 18 decimals.
contract OpenOptionPositionTestGreaterThan18DecimalsCollateral is OpenOptionPositionConstantCollateralPriceTestsBase {
    function setUp() public override {
        vm.startPrank(admin);

        // Creating collateralAsset as the market asset and USDC as the collateral asset.
        collateralAsset = new MockERC20();

        collateralAsset.initialize("Bonkers", "BONK", 22);

        vm.label(address(collateralAsset), "BONK");

        initialCollateralAssetPrice = 1000e8; // $1000

        super.setUpWithController({collateral_: collateralAsset, controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);

        leverageModProxy.setLeverageCriteria({
            marginMin_: getQuoteFromDollarAmount(50e18, collateralAsset), // $50 in collateral terms
            leverageMin_: leverageModProxy.leverageMin(),
            leverageMax_: leverageModProxy.leverageMax()
        });

        setCollateralPrice(initialCollateralAssetPrice);

        vaultProxy.setMaxPositions(3);
        vaultProxy.setMaxPositionsWhitelist(bob, true);
        vaultProxy.setMaxPositionsWhitelist(carol, true);

        initialStableCollateralPerShare = 1e36 / (initialCollateralAssetPrice * 1e10);
    }
}
