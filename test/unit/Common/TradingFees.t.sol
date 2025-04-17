// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract WithdrawAndLeverageFeeTest is OrderHelpers {
    uint256 stableWithdrawFee = 0.005e18; // 0.5%
    uint256 leverageTradingFee = 0.001e18; // 0.1%

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        vaultProxy.setStableWithdrawFee(uint64(stableWithdrawFee));
        vaultProxy.setLeverageTradingFee(uint64(leverageTradingFee));
    }

    function test_deposits_and_withdrawal_fees() public {
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

        uint256 aliceLPBalance = stableModProxy.balanceOf(alice);
        uint256 withdrawalAmount = aliceLPBalance / 4;

        // Withdraw 25%
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: withdrawalAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });
        uint256 aliceCollateralBalance = collateralAsset.balanceOf(alice);
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();
        uint256 stableWithdrawFeeAmount = (100e18 * stableWithdrawFee) / 1e18;

        assertEq(
            aliceCollateralBalanceBefore,
            collateralAsset.balanceOf(alice) + (keeperFee * 4) + 300e18 + stableWithdrawFeeAmount,
            "Alice didn't get the right amount of collateralAsset back after 25% withdraw"
        );
        assertEq(
            vaultProxy.stableCollateralTotal(),
            300.5e18 - ((stableWithdrawFeeAmount * vaultProxy.protocolFeePercentage()) / 1e18),
            "Incorrect stable collateral total after 25% withdraw"
        );

        // Withdraw another 25%
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: withdrawalAmount,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        stableWithdrawFeeAmount += (withdrawalAmount * stableCollateralPerShare * stableWithdrawFee) / 1e36;

        assertApproxEqAbs( // check that Alice received the expected amount of collateralAsset back
            collateralAsset.balanceOf(alice),
            // Alice should receive collateralAsset minus keeper fee and withdraw fee
            aliceCollateralBalance +
                ((stableCollateralPerShare * withdrawalAmount) / 1e18) -
                keeperFee -
                ((((stableCollateralPerShare * withdrawalAmount) / 1e18) * stableWithdrawFee) / 1e18), // withdraw fee
            1e6, // rounding
            "Alice didn't get the right amount of collateralAsset back after second withdraw"
        );
        assertEq(
            collateralAsset.balanceOf(address(orderExecutionModProxy)),
            0,
            "Delayed order should have 0 collateralAsset"
        );
        assertEq(
            aliceCollateralBalanceBefore - (stableWithdrawFeeAmount * vaultProxy.protocolFeePercentage()) / 1e18,
            collateralAsset.balanceOf(address(vaultProxy)) +
                collateralAsset.balanceOf(address(alice)) +
                (keeperFee * 5),
            "Vault should have remaining collateralAsset"
        );

        // Withdraw remainder
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: withdrawalAmount * 2,
            oraclePrice: 2000e8,
            keeperFeeAmount: keeperFee
        });

        assertApproxEqAbs(
            aliceCollateralBalanceBefore - (stableWithdrawFeeAmount * vaultProxy.protocolFeePercentage()) / 1e18,
            collateralAsset.balanceOf(address(alice)) + (keeperFee * 6),
            1e6,
            "Alice should get all her collateralAsset back"
        );
        assertApproxEqAbs(
            collateralAsset.balanceOf(address(vaultProxy)),
            0,
            1e6,
            "Vault should have no collateralAsset"
        );
    }

    function test_deposit_and_leverage_fees() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 2000e8;
        uint256 margin = 100e18;
        uint256 size = 100e18; // 2x

        setCollateralPrice(collateralPrice);

        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 collateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        uint256[] memory balances = new uint256[](10);
        balances[0] = collateralAsset.balanceOf(alice);
        balances[1] = collateralAsset.balanceOf(feeRecipient);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin,
            additionalSize: size,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 tradingFee = (size * leverageTradingFee) / 1e18;
        uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradingFee) / 1e18;

        assertEq(
            stableModProxy.stableCollateralPerShare(),
            collateralPerShareBefore + (((tradingFee - protocolFee) * 1e18) / stableModProxy.totalSupply()),
            "Stable collateral per share should be higher from leverage trade fee"
        );
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            balances[1] + protocolFee,
            "Fee recipient should get protocol fee"
        );

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        // Protocol and trading fees should be doubled as there are leverage trades which take the same amount of fees.
        protocolFee *= 2;
        tradingFee *= 2;

        uint256 aliceLPBalance = stableModProxy.balanceOf(alice);
        uint256 aliceCollateralBalanceBeforeWithdraw = collateralAsset.balanceOf(alice);
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(
            stableCollateralPerShare,
            collateralPerShareBefore + (((tradingFee - protocolFee) * 1e18) / stableModProxy.totalSupply()),
            "Stable collateral per share should be higher from leverage 2 trade fees"
        );
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            balances[1] + protocolFee,
            "Fee recipient should get correct amount of protocol fees after closing"
        );

        // Withdraw half the stable LP tokens
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: aliceLPBalance / 2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        {
            uint256 withdrawalFee = (aliceLPBalance * stableCollateralPerShare * stableWithdrawFee) / 2e36;
            protocolFee += (withdrawalFee * vaultProxy.protocolFeePercentage()) / 1e18;

            assertEq(
                aliceCollateralBalanceBeforeWithdraw,
                collateralAsset.balanceOf(alice) -
                    ((aliceLPBalance * stableCollateralPerShare) / 2e18) +
                    keeperFee +
                    withdrawalFee,
                "Incorrect collateralAsset balance after withdraw"
            );
            assertEq(
                collateralAsset.balanceOf(feeRecipient),
                balances[1] + protocolFee,
                "Fee recipient should get correct amount after withdrawal"
            );
        }

        aliceLPBalance = stableModProxy.balanceOf(alice);
        aliceCollateralBalanceBeforeWithdraw = collateralAsset.balanceOf(alice);
        stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        // Withdraw the remaining stable LP tokens
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: aliceLPBalance,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        assertEq(
            aliceCollateralBalanceBeforeWithdraw,
            collateralAsset.balanceOf(alice) - ((aliceLPBalance * stableCollateralPerShare) / 1e18) + keeperFee,
            "Incorrect collateralAsset balance after withdraw"
        );
        assertEq(stableModProxy.totalSupply(), 0, "Should be 0 totalSupply");
        assertEq(
            stableModProxy.stableCollateralPerShare(),
            1e36 / (collateralPrice * 1e10),
            "Stable collateral per share should be reset"
        );
        // Note that if the withdrawal burns all LP tokens (final withdrawal) then the protocol fee is not taken.
        assertEq(
            collateralAsset.balanceOf(feeRecipient),
            balances[1] + protocolFee,
            "Fee recipient should get correct amount of protocol fees after all transactions"
        );
        assertEq(
            balances[0], // Alice collateralAsset balance before all transactions
            collateralAsset.balanceOf(alice) + (keeperFee * 5) + protocolFee,
            "Alice should get all her collateralAsset back"
        );
        assertEq(collateralAsset.balanceOf(address(vaultProxy)), 0, "There should be no stable collateral in vault");
        assertEq(vaultProxy.stableCollateralTotal(), 0, "There should be no stable collateral accounted for in vault");
    }
}
