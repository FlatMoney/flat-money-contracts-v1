// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Setup} from "../../helpers/Setup.sol";
import "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "forge-std/console2.sol";

contract LeverageTest is OrderHelpers, ExpectRevert {
    struct PositionState {
        LeverageModuleStructs.Position position;
        LeverageModuleStructs.PositionSummary positionSummary;
    }

    function test_leverage_open() public {
        _leverageOpen();
        _leverageOpen();
        _leverageOpen();
    }

    function test_leverage_close() public {
        _leverageClose();
        _leverageClose();
        _leverageClose();
    }

    function test_revert_leverage_open_but_position_creates_bad_debt() public {
        setCollateralPrice(1000e8);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);

        // Effectively remove the max leverage limit so that a position is immediately liquidatable.
        // Immediately liquidatable due to liquidation buffer provided being less than required
        // for the position size.
        leverageModProxy.setLeverageCriteria({
            marginMin_: 0.05e18,
            leverageMin_: 1.5e18,
            leverageMax_: type(uint256).max
        });

        // Announce a position which is immediately liquidatable. This should revert.
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.announceOpenLeverage.selector, alice, 0.05e18, 120e18, 0),
            expectedErrorSignature: "PositionCreatesBadDebt()",
            ignoreErrorArguments: true
        });
    }

    function test_leverage_global_pnl_accounting_after_leverage_order_executions() public {
        setCollateralPrice(1000e8);

        uint256 collateralPerShareBefore = stableModProxy.stableCollateralPerShare();

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 1000e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdAlice = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 120e18,
            additionalSize: 100e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 60e18,
            additionalSize: 50e18,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(750e8);

        // triggers updateGlobalPositionData
        uint256 tokenIdBob2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 0.05e18,
            additionalSize: 0.05e18,
            oraclePrice: 750e8,
            keeperFeeAmount: 0
        });

        setCollateralPrice(500e8);

        // triggers updateGlobalPositionData
        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 0.05e18,
            additionalSize: 0.05e18,
            oraclePrice: 500e8,
            keeperFeeAmount: 0
        });

        PositionState memory positionStateAlice = PositionState({
            position: vaultProxy.getPosition(tokenIdAlice),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdAlice)
        });

        PositionState memory positionStateBob = PositionState({
            position: vaultProxy.getPosition(tokenIdBob),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob)
        });

        PositionState memory positionStateBob2 = PositionState({
            position: vaultProxy.getPosition(tokenIdBob2),
            positionSummary: leverageModProxy.getPositionSummary(tokenIdBob2)
        });

        uint256 stableCollateralTotal = vaultProxy.stableCollateralTotal();
        uint256 stableCollateralPerShare = stableModProxy.stableCollateralPerShare();

        assertEq(positionStateAlice.positionSummary.profitLoss, int256(-100e18), "Alice PnL incorrect");
        assertEq(positionStateBob.positionSummary.profitLoss, int256(-50e18), "Bob PnL incorrect");
        assertEq(positionStateBob2.positionSummary.profitLoss, int256(-0.025e18), "Bob PnL 2 incorrect");
        assertEq(int256(stableCollateralTotal), int256(1000e18), "Stable collateral total shouldn't change");
        assertApproxEqAbs(
            viewer.getMarketSummary().profitLossTotalByLongs,
            positionStateAlice.positionSummary.profitLoss +
                positionStateBob.positionSummary.profitLoss +
                positionStateBob2.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
        assertApproxEqAbs(
            int256(stableCollateralPerShare),
            int256(collateralPerShareBefore) -
                (((positionStateAlice.positionSummary.profitLoss +
                    positionStateBob.positionSummary.profitLoss +
                    positionStateBob2.positionSummary.profitLoss) * 1e18) / int256(stableModProxy.totalSupply())),
            1,
            "Stable collateral per share incorrect"
        );
    }

    function _leverageOpen() internal {
        setCollateralPrice(2000e8);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });
    }

    function _leverageClose() internal {
        setCollateralPrice(2000e8);
        skip(120);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 100e18,
            additionalSize: 100e18,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: 2000e8,
            keeperFeeAmount: 0
        });
    }
}
