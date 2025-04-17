// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import "src/interfaces/IChainlinkAggregatorV3.sol";

contract StableCollateralTotalTest is OrderHelpers {
    // The following tests check the value of stable shares before and after closing all positions on the leverage side.
    // in different scenarios. These tests ensure that when calculating the share value of stable LPs, the value doesn't depend on
    // leverage traders closing their positions because the PnL and funding fees are accounted for when calculating
    // the share price.
    // NOTE: For all the following tests, the funding rates have been disabled given that they create
    // discrepancies in the share value due to the delayed order mechanism.

    function setUp() public override {
        super.setUp();

        disableChainlinkExpiry();
    }

    function test_LP_share_value_change_no_price_change_long_skew() public {
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

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Note that keeper fee is taken 6 times in the form of collateralAsset.
        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    function test_LP_share_value_change_no_price_change_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
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

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    function test_LP_share_value_change_price_increase_long_skew() public {
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

        // The price of ETH increases by 100%.
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    function test_LP_share_value_change_price_increase_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
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

        // The price of ETH increases by 100%.
        uint256 newCollateralPrice = 2000e8;
        setCollateralPrice(newCollateralPrice);

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    function test_LP_share_value_change_price_decrease_long_skew() public {
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

        // The price of ETH decreases by 10%.
        uint256 newCollateralPrice = 900e8;
        setCollateralPrice(newCollateralPrice);

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    function test_LP_share_value_change_price_decrease_short_skew() public {
        vm.startPrank(alice);

        uint256 aliceBalanceBefore = collateralAsset.balanceOf(alice);
        uint256 stableDeposit = 200e18;
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

        // The price of ETH decreases by 10%.
        uint256 newCollateralPrice = 900e8;
        setCollateralPrice(newCollateralPrice);

        skip(2 days);

        uint256 shareValue1 = stableModProxy.stableCollateralPerShare();

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        uint256 shareValue2 = stableModProxy.stableCollateralPerShare();

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // We are checking that `stableCollateralPerShare` does not change after closing the positions.
        // This is because that function calls `stableCollateralTotalAfterSettlement` which accounts for PnL
        // and funding fees. This accounting doesn't depend on the leverage positions being closed.
        // It just depends on the PnL and funding fees accrued by the leverage positions.
        // For this and the following tests, funding rates have been disabled.
        assertEq(shareValue1, shareValue2, "LP share value should not change");

        // Remove the LP liquidity.
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        assertApproxEqRel(
            collateralAsset.balanceOf(alice),
            aliceBalanceBefore - (mockKeeperFee.getKeeperFee() * 6),
            0.000001e18,
            "Alice should have original amount of tokens back after exiting the market"
        );

        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have 0 collateralAsset balance"
        );
    }

    // TODO: This test fails but the solution isn't straightforward.
    function test_LP_share_value_change_when_price_increases_between_announcement_and_execution() public {
        vm.startPrank(alice);

        uint256 stableDeposit = 200e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        skip(1 minutes);

        setCollateralPrice(1000e8);

        announceStableDeposit({
            traderAccount: alice,
            depositAmount: stableDeposit,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Price changed from 1000e8 to 2000e8 between announcement and execution.
        setCollateralPrice(2000e8);

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        executeStableDeposit(keeper, alice, 2000e8);
    }
}
