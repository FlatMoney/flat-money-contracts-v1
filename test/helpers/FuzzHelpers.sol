// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {OrderHelpers} from "./OrderHelpers.sol";

abstract contract FuzzHelpers is OrderHelpers {
    struct DepositLeverageParams {
        address trader;
        address keeper;
        uint256 collateralPrice;
        uint256 stableDeposit;
        uint256 margin1;
        uint256 size1;
        uint256 margin2;
        uint256 size2;
        uint256 priceMultiplier;
    }

    function depositLeverageWithdrawAll(DepositLeverageParams memory params) public {
        uint256 traderWethBalanceBefore = WETH.balanceOf(params.trader);

        vm.startPrank(params.trader);

        // Deposit stable LP
        announceAndExecuteDeposit({
            traderAccount: params.trader,
            keeperAccount: params.keeper,
            depositAmount: params.stableDeposit,
            oraclePrice: params.collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH collateral, 30 ETH additional size (4x leverage)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: params.trader,
            keeperAccount: params.keeper,
            margin: params.margin1,
            additionalSize: params.size1,
            oraclePrice: params.collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId2;

        if (params.margin2 > 0) {
            tokenId2 = announceAndExecuteLeverageOpen({
                traderAccount: params.trader,
                keeperAccount: params.keeper,
                margin: params.margin2,
                additionalSize: params.size2,
                oraclePrice: params.collateralPrice,
                keeperFeeAmount: 0
            });
        }

        setWethPrice((params.collateralPrice * params.priceMultiplier) / 1e18);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: params.trader,
            keeperAccount: params.keeper,
            oraclePrice: (params.collateralPrice * params.priceMultiplier) / 1e18,
            keeperFeeAmount: 0
        });

        if (params.margin2 > 0) {
            // Close second position
            announceAndExecuteLeverageClose({
                tokenId: tokenId2,
                traderAccount: params.trader,
                keeperAccount: params.keeper,
                oraclePrice: (params.collateralPrice * params.priceMultiplier) / 1e18,
                keeperFeeAmount: 0
            });
        }

        {
            uint256 traderStableBalance = stableModProxy.balanceOf(params.trader);

            // Withdraw stable LP
            announceAndExecuteWithdraw({
                traderAccount: params.trader,
                keeperAccount: params.keeper,
                withdrawAmount: traderStableBalance,
                oraclePrice: (params.collateralPrice * params.priceMultiplier) / 1e18,
                keeperFeeAmount: 0
            });
        }

        if (params.priceMultiplier == 1e18) {
            assertApproxEqAbs(
                traderWethBalanceBefore - (mockKeeperFee.getKeeperFee() * (params.margin2 > 0 ? 6 : 4)),
                WETH.balanceOf(params.trader),
                1e6,
                "Trader didn't receive all the WETH back"
            );
        }

        assertLt(
            WETH.balanceOf(address(vaultProxy)),
            1e6,
            "Vault should have no more than dust WETH balance remaining"
        );
    }
}
