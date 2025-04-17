// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "../../helpers/Setup.sol";
import {OrderHelpers} from "../../helpers/OrderHelpers.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "forge-std/console2.sol";

abstract contract OptionMaxPositionsConstantCollateralPriceTestsBase is Setup, OrderHelpers, ExpectRevert {
    struct PositionState {
        LeverageModuleStructs.Position position;
        LeverageModuleStructs.PositionSummary positionSummary;
    }

    uint256 initialCollateralAssetPrice;
    uint256 initialStableCollateralPerShare;

    function test_option_max_positions() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
        });

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
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

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceOpenLeverage.selector,
                carol,
                carolPositionDetails.margin,
                carolPositionDetails.additionalSize,
                0
            ),
            expectedErrorSignature: "MaxPositionsReached()",
            ignoreErrorArguments: true
        });

        // Close all positions without issue
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdCarol,
            traderAccount: carol,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob2,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
    }

    function test_option_max_positions_execute() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
        });

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
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

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        // Announce orders from both Bob and Carol at the same time
        announceOpenLeverage({
            traderAccount: bob,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            keeperFeeAmount: 0
        });
        announceOpenLeverage({
            traderAccount: carol,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize,
            keeperFeeAmount: 0
        });

        skip(uint256(orderAnnouncementModProxy.minExecutabilityAge())); // must reach minimum executability time

        // Bob's order should be executed but Carol's should revert
        uint256 tokenIdBob2 = executeOpenLeverage(keeper, bob, 1000e8);

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(OrderHelpers.executeOpenLeverage.selector, keeper, carol, 1000e8, false),
            expectedErrorSignature: "MaxPositionsReached()",
            ignoreErrorArguments: true
        });

        // Skip some time so that the order expires.
        skip(orderExecutionModProxy.maxExecutabilityAge() + 1);
        // Cancel Carol's pending order.
        orderExecutionModProxy.cancelExistingOrder(carol);

        // Close all positions without issue
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdCarol,
            traderAccount: carol,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob2,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
    }

    function test_option_max_positions_views() public {
        InitialDepositDetails memory aliceDepositDetails = InitialDepositDetails({
            depositAmount: getQuoteFromDollarAmount(10_000e18, collateralAsset) // Deposit $10_000 worth of collateral
        });
        InitialPositionDetails memory bobPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
        });

        InitialPositionDetails memory carolPositionDetails = InitialPositionDetails({
            margin: getQuoteFromDollarAmount(1_000e18, collateralAsset),
            additionalSize: getQuoteFromDollarAmount(1_000e18, collateralAsset)
        });

        assertEq(vaultProxy.isPositionOpenWhitelisted(alice), false);
        assertEq(vaultProxy.isPositionOpenWhitelisted(bob), true);
        assertEq(vaultProxy.isPositionOpenWhitelisted(carol), true);

        setCollateralPrice(1000e8);

        // First deposit mint doesn't use offchain oracle price
        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: aliceDepositDetails.depositAmount,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256 tokenIdBob = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        uint256[] memory maxPositionIds = vaultProxy.getMaxPositionIds();
        assertEq(maxPositionIds.length, 1);
        assertEq(maxPositionIds[0], tokenIdBob);
        assertEq(vaultProxy.isMaxPositionsReached(), false);

        uint256 tokenIdCarol = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: carolPositionDetails.margin,
            additionalSize: carolPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        maxPositionIds = vaultProxy.getMaxPositionIds();
        assertEq(maxPositionIds.length, 2);
        assertEq(maxPositionIds[0], tokenIdBob);
        assertEq(maxPositionIds[1], tokenIdCarol);
        assertEq(vaultProxy.isMaxPositionsReached(), false);

        uint256 tokenIdBob2 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: bobPositionDetails.margin,
            additionalSize: bobPositionDetails.additionalSize,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });

        assertEq(tokenIdBob, 0);
        assertEq(tokenIdCarol, 1);
        assertEq(tokenIdBob2, 2);

        maxPositionIds = vaultProxy.getMaxPositionIds();
        assertEq(maxPositionIds.length, 3);
        assertEq(maxPositionIds[0], tokenIdBob);
        assertEq(maxPositionIds[1], tokenIdCarol);
        assertEq(maxPositionIds[2], tokenIdBob2);
        assertEq(vaultProxy.isMaxPositionsReached(), true);

        // Close all positions without issue
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdCarol,
            traderAccount: carol,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteLeverageClose({
            tokenId: tokenIdBob2,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
        announceAndExecuteWithdraw({
            traderAccount: alice,
            keeperAccount: keeper,
            withdrawAmount: stableModProxy.balanceOf(alice),
            oraclePrice: 1000e8,
            keeperFeeAmount: 0
        });
    }
}

// NOTE: These tests run against a market asset with a different number od fecimals

/// @dev Test contract with collateral asset using less than 18 decimals.
contract OptionMaxPositionsTestLessThan18DecimalsCollateral is OptionMaxPositionsConstantCollateralPriceTestsBase {
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

        initialStableCollateralPerShare =
            (1e18 * (10 ** collateralAsset.decimals())) /
            (initialCollateralAssetPrice * 1e10);
    }
}

/// @dev Test contract with collateral asset using 18 decimals.
contract OptionMaxPositionsTestEqualTo18DecimalsCollateral is OptionMaxPositionsConstantCollateralPriceTestsBase {
    function setUp() public override {
        initialCollateralAssetPrice = 1000e8; // $1000

        super.setUpDefaultWithController({controller_: Setup.ControllerType.OPTIONS});

        vm.startPrank(admin);

        setCollateralPrice(initialCollateralAssetPrice);

        vaultProxy.setMaxPositions(3);
        vaultProxy.setMaxPositionsWhitelist(bob, true);
        vaultProxy.setMaxPositionsWhitelist(carol, true);

        initialStableCollateralPerShare =
            (1e18 * (10 ** collateralAsset.decimals())) /
            (initialCollateralAssetPrice * 1e10);
    }
}

/// @dev Test contract with collateral asset using greater than 18 decimals.
contract OptionMaxPositionsTestGreaterThan18DecimalsCollateral is OptionMaxPositionsConstantCollateralPriceTestsBase {
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

        initialStableCollateralPerShare =
            (1e18 * (10 ** collateralAsset.decimals())) /
            (initialCollateralAssetPrice * 1e10);
    }
}
