// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract OpenPositionTest is OrderHelpers {
    function test_price_increase_no_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId1 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 70e18,
            additionalSize: 70e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 3) - 180e18,
            "Alice's balance incorrect after creating the market"
        ); // 100 deposit to stable LP, 80 deposit into 2 leveraged positions

        // ERC721 token assertions:
        {
            (uint256 buyPrice, ) = oracleModProxy.getPrice(address(vaultProxy.collateral()));
            // Position 0:
            LeverageModuleStructs.Position memory position0 = vaultProxy.getPosition(tokenId);
            assertEq(position0.averagePrice, buyPrice, "Entry price is not correct");
            assertEq(position0.marginDeposited, 10e18, "Margin deposited is not correct");
            assertEq(position0.additionalSize, 30e18, "Size is not correct");
            assertEq(tokenId, 0, "Token ID is not correct");

            // Position 1:
            LeverageModuleStructs.Position memory position1 = vaultProxy.getPosition(tokenId1);
            assertEq(position1.averagePrice, buyPrice, "Entry price is not correct");
            assertEq(position1.marginDeposited, 70e18, "Margin deposited is not correct");
            assertEq(position1.additionalSize, 70e18, "Size is not correct");
            assertEq(tokenId1, 1, "Token ID is not correct");
        }

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.PositionSummary memory positionSummary1 = leverageModProxy.getPositionSummary(
                tokenId1
            );
            uint256 collateralPerShareBefore = stableModProxy.stableCollateralPerShare();

            // Check that before the collateralAsset price change, there is no profit or loss change
            assertEq(positionSummary0.profitLoss, 0, "Pnl for user 0 is not correct");
            assertEq(positionSummary1.profitLoss, 0, "Pnl for user 1 is not correct");
            assertEq(
                positionSummary0.marginAfterSettlement,
                10e18,
                "Margin after settlement for user 0 is not correct"
            ); // full margin available
            assertEq(
                positionSummary1.marginAfterSettlement,
                70e18,
                "Margin after settlement for user 1 is not correct"
            ); // full margin available

            // Check that the stableCollateralPerShare hasn't changed because the leverage traders are not winning or losing.
            assertEq(collateralPerShareBefore, collateralPerShareBeforeDeposit, "Collateral per share is incorrect");
        }

        // Mock collateralAsset Chainlink price to $2k (100% increase)
        setCollateralPrice(2000e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.PositionSummary memory positionSummary1 = leverageModProxy.getPositionSummary(
                tokenId1
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is profit on the 2 positions
            assertEq(marketSummary.profitLossTotalByLongs, 50e18, "Total PnL is not correct");
            assertEq(positionSummary0.profitLoss, 15e18, "Pnl for user 0 is not correct");
            assertEq(positionSummary1.profitLoss, 35e18, "Pnl for user 1 is not correct");
            assertEq(
                marketSummary.profitLossTotalByLongs,
                positionSummary0.profitLoss + positionSummary1.profitLoss,
                "Total PnL does not equal sum of individual PnLs"
            );
            assertEq(
                positionSummary0.marginAfterSettlement,
                25e18,
                "Margin after settlement for user 0 is not correct"
            ); // additional margin available
            assertEq(
                positionSummary1.marginAfterSettlement,
                105e18,
                "Margin after settlement for user 1 is not correct"
            ); // additional margin available
            // Check that the stable LP has half the collateral remaining because the leverage traders are winning
            assertEq(collateralPerShare, collateralPerShareBeforeDeposit / 2, "Collateral per share is incorrect");
        }
    }

    function test_price_decrease_no_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 70e18,
            additionalSize: 70e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 3) - 180e18,
            "Alice's balance is incorrect"
        ); // 100 deposit to stable LP, 80 deposit into 2 leveraged positions

        // Mock collateralAsset Chainlink price to $800 (20% decrease)
        setCollateralPrice(800e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.PositionSummary memory positionSummary1 = leverageModProxy.getPositionSummary(
                tokenId2
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is loss on the 2 positions
            assertEq(marketSummary.profitLossTotalByLongs, -25e18, "Total PnL is not correct");
            assertEq(positionSummary0.profitLoss, -75e17, "Pnl for user 0 is not correct");
            assertEq(positionSummary1.profitLoss, -175e17, "Pnl for user 1 is not correct");
            assertEq(
                marketSummary.profitLossTotalByLongs,
                positionSummary0.profitLoss + positionSummary1.profitLoss,
                "Total PnL does not equal sum of individual PnLs"
            );
            assertEq(positionSummary0.marginAfterSettlement, 25e17, "Margin after settlement is incorrect for user 0"); // less margin available
            assertEq(positionSummary1.marginAfterSettlement, 525e17, "Margin after settlement is incorrect for user 1"); // less margin available
            // Check that the stable LP has 25% more collateral remaining because the leverage traders are losing
            assertEq(
                collateralPerShare,
                (collateralPerShareBeforeDeposit * 125) / 100,
                "Collateral per share is incorrect"
            );
        }
    }

    function test_price_increase_long_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        int256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 margin = 120e18;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: uint256(stableDeposit),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: margin,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(collateralAsset.balanceOf(alice), aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 2) - 220e18); // 100 deposit to stable LP, 120 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $2k (100% increase)
        setCollateralPrice(2000e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is profit on the position
            assertEq(marketSummary.profitLossTotalByLongs, 60e18);
            assertEq(positionSummary0.profitLoss, 60e18);
            assertEq(positionSummary0.marginAfterSettlement, int256(margin) + positionSummary0.profitLoss); // additional margin available
            // Check that the stable LP has less than half the collateral remaining because the leverage trader is winning and the skew is long
            // More precisely, the stable LP has 40% of the collateral remaining because the leverage trader is winning and the skew is long.
            assertEq(
                collateralPerShare,
                (collateralPerShareBeforeDeposit * 40) / 100,
                "Collateral per share is incorrect"
            );
            assertEq(
                int256(collateralPerShare),
                (((stableDeposit) - positionSummary0.profitLoss) * int256(collateralPerShareBeforeDeposit)) /
                    stableDeposit
            ); // should be the same assertion as the one above
        }
    }

    function test_price_increase_stable_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        int256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 margin = 80e18;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: uint256(stableDeposit),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 80 ETH collateral, 80 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: margin,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertEq(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 2) - 180e18,
            "Alice's balance is incorrect"
        ); // 100 deposit to stable LP, 80 deposit into 1 leveraged position

        // Mock collateralAsset Chainlink price to $2k (100% increase)
        setCollateralPrice(2000e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is profit on the position
            assertEq(marketSummary.profitLossTotalByLongs, 40e18);
            assertEq(positionSummary0.profitLoss, 40e18);
            assertEq(positionSummary0.marginAfterSettlement, int256(margin) + positionSummary0.profitLoss); // additional margin available

            // Check that the stable LP has more than half the collateral remaining because the leverage trader is winning and the skew is to stable LPs
            // More precisely, the stable LP has 60% of the collateral remaining because the leverage trader is winning and the skew is to stable LPs.
            assertEq(
                collateralPerShare,
                (collateralPerShareBeforeDeposit * 60) / 100,
                "Collateral per share is incorrect"
            );
            assertEq(
                int256(collateralPerShare),
                ((stableDeposit - positionSummary0.profitLoss) * int256(collateralPerShareBeforeDeposit)) /
                    stableDeposit
            ); // should be the same assertion as the one above
        }
    }

    function test_price_decrease_long_skew() public {
        vm.startPrank(alice);

        int256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 margin = 120e18;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: uint256(stableDeposit),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 120 ETH collateral, 120 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: margin,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Mock collateralAsset Chainlink price to $800 (20% decrease)
        setCollateralPrice(800e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is loss on the position
            assertEq(marketSummary.profitLossTotalByLongs, -30e18, "Incorrect profit-loss total");
            assertEq(positionSummary0.profitLoss, -30e18, "Incorrect position profit-loss");
            assertEq(
                marketSummary.profitLossTotalByLongs,
                positionSummary0.profitLoss,
                "Profit-loss total doesn't match position"
            );
            assertEq(positionSummary0.marginAfterSettlement, 90e18, "Incorrect available margin"); // less margin available
            // Check that the stable LP has 30% more collateral remaining because the leverage traders are losing
            assertEq(
                collateralPerShare,
                (collateralPerShareBeforeDeposit * 130) / 100,
                "Incorrect collateral per share"
            );
        }
    }

    function test_price_decrease_stable_skew() public {
        vm.startPrank(alice);

        int256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 margin = 80e18;
        uint256 collateralPerShareBeforeDeposit = stableModProxy.stableCollateralPerShare();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: uint256(stableDeposit),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });
        // 80 ETH collateral, 80 ETH additional size (2x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: margin,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Mock collateralAsset Chainlink price to $800 (20% decrease)
        setCollateralPrice(800e8);

        // PnL assertions:
        {
            LeverageModuleStructs.PositionSummary memory positionSummary0 = leverageModProxy.getPositionSummary(
                tokenId
            );
            LeverageModuleStructs.MarketSummary memory marketSummary = viewer.getMarketSummary();

            uint256 collateralPerShare = stableModProxy.stableCollateralPerShare();

            // Check that there is loss on the position
            assertEq(marketSummary.profitLossTotalByLongs, -20e18);
            assertEq(positionSummary0.profitLoss, -20e18);
            assertEq(marketSummary.profitLossTotalByLongs, positionSummary0.profitLoss);
            assertEq(positionSummary0.marginAfterSettlement, 60e18); // less margin available
            // Check that the stable LP has 20% more collateral remaining because the leverage traders are losing
            assertEq(
                collateralPerShare,
                (collateralPerShareBeforeDeposit * 120) / 100,
                "Collateral per share is incorrect"
            );
        }
    }
}
