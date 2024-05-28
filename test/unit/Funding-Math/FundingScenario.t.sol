// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Setup} from "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";
import {FlatcoinErrors} from "src/libraries/FlatcoinErrors.sol";
import "src/interfaces/IChainlinkAggregatorV3.sol";

/// @dev These tests replicate the rounding issue found using fuzzing.
contract FundingScenarioTest is Setup, OrderHelpers, ExpectRevert {
    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        vaultProxy.setMaxFundingVelocity(0.03e18);

        FlatcoinStructs.OnchainOracle memory onchainOracle = FlatcoinStructs.OnchainOracle(
            wethChainlinkAggregatorV3,
            type(uint32).max // Effectively disable oracle expiry.
        );
        FlatcoinStructs.OffchainOracle memory offchainOracle = FlatcoinStructs.OffchainOracle(
            IPyth(address(mockPyth)),
            0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace,
            60, // max age of 60 seconds
            1000
        );

        oracleModProxy.setAssetAndOracles({
            _asset: address(WETH),
            _onchainOracle: onchainOracle,
            _offchainOracle: offchainOracle
        });
    }

    function test_accounting_colateralnet1_violation_scenario1_due_to_funding_settlement() public {
        uint256 collateralPrice = 1e10;
        setWethPrice(collateralPrice);

        // Deposit stable LP
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 2.926407945860964000326e21,
            oraclePrice: 1e10,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 4.513833250040474703468e21,
            additionalSize: 2.256916625020237351734e21,
            oraclePrice: 1e10,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 2.004337430014635806153e21,
            additionalSize: 1.132714293543732176757e21,
            oraclePrice: 1e10,
            keeperFeeAmount: 0
        });

        uint256 newCollateralPrice = (1e10 * 4.472344585e18) / 1e18;
        setWethPrice(newCollateralPrice);

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
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        {
            uint256 traderStableBalance = stableModProxy.balanceOf(alice);

            // Withdraw stable LP
            announceAndExecuteWithdraw({
                traderAccount: alice,
                keeperAccount: keeper,
                withdrawAmount: traderStableBalance,
                oraclePrice: newCollateralPrice,
                keeperFeeAmount: 0
            });
        }

        assertLt(
            WETH.balanceOf(address(vaultProxy)),
            1e6,
            "Vault should have no more than dust WETH balance remaining"
        );
    }

    function test_accounting_colateralnet1_violation_scenario2_due_to_funding_settlement() public {
        uint256 collateralPrice = 1e10;
        setWethPrice(collateralPrice);

        uint256 stableDeposit = 1e18;
        uint256 priceMultiplier = 2.6636497364e18;
        uint256 margin1 = 5e16;
        uint256 additionalSize1 = 2.48012881914469256e17;
        uint256 margin2 = 5e16;
        uint256 additionalSize2 = 9.27677987428418611e17;

        // Deposit stable LP
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: margin1,
            additionalSize: additionalSize1,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: margin2,
            additionalSize: additionalSize2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 newPrice = (collateralPrice * priceMultiplier) / 1e18;
        setWethPrice(newPrice);

        // Close first position
        announceAndExecuteLeverageClose({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            oraclePrice: newPrice,
            keeperFeeAmount: 0
        });

        // Close second position
        announceAndExecuteLeverageClose({
            tokenId: tokenId2,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: newPrice,
            keeperFeeAmount: 0
        });

        {
            uint256 traderStableBalance = stableModProxy.balanceOf(alice);

            // Withdraw stable LP
            announceAndExecuteWithdraw({
                traderAccount: alice,
                keeperAccount: keeper,
                withdrawAmount: traderStableBalance,
                oraclePrice: newPrice,
                keeperFeeAmount: 0
            });
        }

        assertLt(
            WETH.balanceOf(address(vaultProxy)),
            1e6,
            "Vault should have no more than dust WETH balance remaining"
        );
    }
}
