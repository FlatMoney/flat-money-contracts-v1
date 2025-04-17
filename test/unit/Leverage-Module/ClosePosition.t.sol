// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

contract ClosePositionTest is OrderHelpers, ExpectRevert {
    function test_close_position_no_price_change() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

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

        uint256 stableCollateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 stableCollateralPerShareAfter1 = stableModProxy.stableCollateralPerShare();
        assertApproxEqAbs(
            stableCollateralPerShareBefore,
            stableCollateralPerShareAfter1,
            1e6, // rounding error only
            "stableCollateralPerShare should not change"
        );

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 stableCollateralPerShareAfter2 = stableModProxy.stableCollateralPerShare();
        assertApproxEqAbs(
            stableCollateralPerShareBefore,
            stableCollateralPerShareAfter2,
            1e6, // rounding error only
            "stableCollateralPerShare should not change"
        );
        assertEq(
            aliceBalanceBefore - mockKeeperFee.getKeeperFee() * 5,
            collateralAsset.balanceOf(alice) + stableDeposit,
            "Alice collateral balance incorrect"
        );
    }

    function test_close_position_price_increase() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId0 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // Mock collateralAsset Chainlink price to $2000 (100% increase)
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        // 70 ETH collateral, 70 ETH additional size (2x leverage)
        uint256 tokenId1 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 70e18,
            additionalSize: 70e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId0,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId1,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        assertGt(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice),
            "Alice's collateralAsset balance should decrease"
        ); // Alice still has the stable LP deposit to withdraw

        // Withdraw stable deposit
        // Have Bob deposit some amount first so that Alice's full withdrawal doesn't revert on minimum liquidity
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // TODO: Modify `deposit` and `withdraw` function to account for pnl settlement.
        assertEq(
            aliceBalanceBefore - (keeperFee * 2 + keeperFee2 * 4),
            collateralAsset.balanceOf(alice),
            "Alice should have her stable deposit back"
        );
    }

    function test_close_position_price_decrease() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;
        uint256 keeperFee = mockKeeperFee.getKeeperFee();

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });
        // 20 ETH collateral, 20 ETH additional size (2x leverage)
        uint256 tokenId0 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 20e18,
            additionalSize: 20e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // Mock collateralAsset Chainlink price to $900 (10% decrease)
        uint256 newCollateralPrice = 900e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        // 10 ETH collateral, 50 ETH additional size (6x leverage)
        uint256 tokenId1 = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 50e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId0,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId1,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Withdraw stable deposit
        // Have Bob deposit some amount first so that Alice's full withdrawal doesn't revert on minimum liquidity
        announceAndExecuteDeposit({
            traderAccount: bob,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        assertGt(
            aliceBalanceBefore,
            collateralAsset.balanceOf(alice),
            "Alice's collateralAsset balance should increase"
        ); // Alice still has the stable LP deposit to withdraw
        assertApproxEqAbs(
            aliceBalanceBefore - (keeperFee * 2 + keeperFee2 * 4),
            collateralAsset.balanceOf(alice),
            1e6,
            "Alice should get her deposit back"
        ); // allow for some small rounding error
    }

    // The collateralNet in the FlatcoinVault is intended to be non-decreasing.
    // However, computational errors can lead to violations of this invariant.
    // The issue arises from the FlatcoinVault.sol::updateGlobalPositionData()#L186, where _globalPositions is deleted.
    // This can lead to discrepancies in the collateralNet, especially.
    // See audit issue 106 description for the v2-update contest on Sherlock.
    function test_invariant_violation_when_closing_last_position() public {
        uint256 collateralPrice = 1000e8;
        uint256 stableDeposit = 10e18;

        setCollateralPrice(collateralPrice);
        vm.startPrank(admin);

        controllerModProxy.setMaxFundingVelocity(0.03e18 - 1);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        address[10] memory adrs;
        uint256 n = 4;
        uint256 size = 1e18 + 1;

        adrs[1] = makeAddr("trader1");
        adrs[2] = makeAddr("trader2");
        adrs[3] = makeAddr("trader3");
        adrs[4] = makeAddr("trader4");

        for (uint256 i = 1; i <= n; i++) {
            vm.startPrank(admin);
            collateralAsset.transfer(adrs[i], 100e18);
        }
        for (uint256 i = 1; i <= n; i++) {
            announceOpenLeverage(adrs[i], size, size, 0);
        }
        skip(10); // must reach minimum executability time

        uint256[9] memory tokenIds;
        for (uint256 i = 1; i <= n; i++) {
            tokenIds[i] = executeOpenLeverage(keeper, adrs[i], collateralPrice);
        }

        collateralPrice += 1e8 + 1;
        setCollateralPrice(collateralPrice);

        for (uint256 i = 1; i <= n; i++) {
            LeverageModuleStructs.Position memory position = vaultProxy.getPosition(tokenIds[i]);
            uint256 marginAdjustment = position.marginDeposited / 9;
            uint256 additionalSizeAdjustment = position.additionalSize / 9;
            announceAdjustLeverage(adrs[i], tokenIds[i], int256(marginAdjustment), int(additionalSizeAdjustment), 0);
        }

        skip(10); // must reach minimum executability time

        for (uint256 i = 1; i <= n; i++) {
            executeAdjustLeverage(keeper, adrs[i], collateralPrice);
        }

        for (uint256 i = n; i >= 1; i--) {
            announceCloseLeverage(adrs[i], tokenIds[i], 0);
        }
        skip(10); // must reach minimum executability time

        for (uint256 i = n; i >= 1; i--) {
            executeCloseLeverage(keeper, adrs[i], collateralPrice);
        }
    }

    function test_revert_close_position_after_position_liquidated() public {
        uint256 tokenId = announceAndExecuteDepositAndLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 liqPrice = viewer.liquidationPrice(tokenId);
        uint256 newCollateralPrice = (liqPrice - 1e10) / 1e10;

        setCollateralPrice(newCollateralPrice);

        announceCloseLeverage({traderAccount: alice, tokenId: tokenId, keeperFeeAmount: 0});

        vm.startPrank(liquidator);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        liquidationModProxy.liquidate(tokenIds);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge()));

        vm.startPrank(keeper);
        bytes[] memory priceUpdateData = getPriceUpdateData(newCollateralPrice);

        _expectRevertWithCustomError({
            target: address(orderExecutionModProxy),
            callData: abi.encodeWithSelector(OrderExecutionModule.executeOrder.selector, alice, priceUpdateData),
            expectedErrorSignature: "OrderInvalid(address)",
            errorData: abi.encodeWithSelector(OrderExecutionModule.OrderInvalid.selector, alice),
            value: 1
        });
    }
}
