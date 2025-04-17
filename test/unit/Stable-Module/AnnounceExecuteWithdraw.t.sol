// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract AnnounceExecuteWithdrawTest is OrderHelpers {
    function test_deposits_and_withdrawal() public {
        vm.startPrank(admin);
        vaultProxy.setStableWithdrawFee(0);
        vaultProxy.setLeverageTradingFee(0);

        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        // Uses offchain oracle price on deposit to mint deposit tokens
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 200e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        uint256 totalLPMinted = stableModProxy.balanceOf(alice);
        uint256 withdrawalAmount1 = totalLPMinted / 4;
        uint256 withdrawalAmount2 = totalLPMinted - withdrawalAmount1;

        // Withdraw 25%
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: withdrawalAmount1,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        // Withdraw the remaining 75%
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: withdrawalAmount2,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            aliceCollateralBalanceBefore,
            collateralAsset.balanceOf(alice) + (keeperFee * 5),
            "Alice didn't get all her collateralAsset back"
        );
        assertEq(
            collateralAsset.balanceOf(address(orderExecutionModProxy)),
            0,
            "Delayed order should have 0 collateralAsset"
        );
        assertEq(collateralAsset.balanceOf(address(vaultProxy)), 0, "Vault should have 0 collateralAsset");
        assertEq(stableModProxy.totalSupply(), 0, "Stable LP should have 0 supply");
    }
}
