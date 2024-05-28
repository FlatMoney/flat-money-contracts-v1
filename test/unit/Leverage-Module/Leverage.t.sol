// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Setup} from "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import {FlatcoinStructs} from "../../../src/libraries/FlatcoinStructs.sol";
import {FlatcoinErrors} from "../../../src/libraries/FlatcoinErrors.sol";

import "forge-std/console2.sol";

contract LeverageTest is Setup, OrderHelpers, ExpectRevert {
    struct PositionState {
        FlatcoinStructs.Position position;
        FlatcoinStructs.PositionSummary positionSummary;
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
        setWethPrice(1000e8);

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
            _marginMin: 0.05e18,
            _leverageMin: 1.5e18,
            _leverageMax: type(uint256).max
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
        setWethPrice(1000e8);

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

        setWethPrice(750e8);

        // triggers updateGlobalPositionData
        uint256 tokenIdBob2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 0.05e18,
            additionalSize: 0.05e18,
            oraclePrice: 750e8,
            keeperFeeAmount: 0
        });

        setWethPrice(500e8);

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
            leverageModProxy.getMarketSummary().profitLossTotalByLongs,
            positionStateAlice.positionSummary.profitLoss +
                positionStateBob.positionSummary.profitLoss +
                positionStateBob2.positionSummary.profitLoss,
            1,
            "Global market profit and loss total incorrect"
        );
        assertApproxEqAbs(
            int256(stableCollateralPerShare),
            int256(1e18) -
                (((positionStateAlice.positionSummary.profitLoss +
                    positionStateBob.positionSummary.profitLoss +
                    positionStateBob2.positionSummary.profitLoss) * 1e18) / int256(stableModProxy.totalSupply())),
            1,
            "Stable collateral per share incorrect"
        );
    }

    // TODO: Consider moving helper functions to a separate contract

    function _leverageOpen() internal {
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
        setWethPrice(2000e8);
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
