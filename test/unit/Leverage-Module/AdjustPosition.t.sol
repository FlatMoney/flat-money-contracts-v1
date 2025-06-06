// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";

import "../../helpers/OrderHelpers.sol";

import "forge-std/console2.sol";

contract AdjustPositionTest is OrderHelpers, ExpectRevert {
    struct PositionState {
        uint256 collateralPrice;
        LeverageModuleStructs.Position position;
        LeverageModuleStructs.PositionSummary positionSummary;
        LeverageModuleStructs.MarketSummary marketSummary;
        FlatcoinVaultStructs.GlobalPositions globalPositions;
        uint256 collateralPerShare;
    }

    uint256 leverageTradingFee = 0.001e18; // 0.1%

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        vaultProxy.setLeverageTradingFee(uint64(leverageTradingFee));
    }

    /**
     * Reverts
     */
    function test_revert_adjust_position_when_leverage_too_small() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // -26 ETH size, no change in margin
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAndExecuteLeverageAdjust.selector,
                tokenId,
                alice,
                keeper,
                0,
                -26e18,
                collateralPrice,
                0
            ),
            expectedErrorSignature: "LeverageTooLow(uint256,uint256)",
            errorData: abi.encodeWithSelector(
                LeverageModule.LeverageTooLow.selector,
                1.5e18,
                1e18 + (4e18 * 1e18) / (10e18 - vaultProxy.getTradeFee(26e18) - mockKeeperFee.getKeeperFee())
            )
        });
    }

    function test_revert_adjust_position_when_caller_not_position_owner() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // +10 ETH margin, no change in size
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAndExecuteLeverageAdjust.selector,
                tokenId,
                bob,
                keeper,
                10e18,
                0,
                collateralPrice,
                0
            ),
            expectedErrorSignature: "NotTokenOwner(uint256,address)",
            errorData: abi.encodeWithSelector(ICommonErrors.NotTokenOwner.selector, tokenId, bob)
        });
    }

    function test_revert_adjust_position_when_adjustments_not_specified() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // no change in margin, no change in size
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAndExecuteLeverageAdjust.selector,
                tokenId,
                alice,
                keeper,
                0,
                0,
                collateralPrice,
                0
            ),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.ZeroValue.selector,
                "marginAdjustment|additionalSizeAdjustment"
            )
        });
    }

    function test_revert_adjust_position_when_withdrawing_more_margin_then_exists() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // -20 ETH margin, no change in size
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAndExecuteLeverageAdjust.selector,
                tokenId,
                alice,
                keeper,
                -20e18,
                0,
                collateralPrice,
                0
            ),
            expectedErrorSignature: "ValueNotPositive(string)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.ValueNotPositive.selector,
                "newMarginAfterSettlement|newAdditionalSize"
            )
        });
    }

    function test_revert_adjust_position_when_adjusted_position_creates_bad_debt() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);

        // Effectively remove the max leverage limit so that a position can be immediately liquidatable.
        // Immediately liquidatable due to liquidation buffer/margin provided being less than required
        // for the position size.
        leverageModProxy.setLeverageCriteria({
            marginMin_: 0.05e18,
            leverageMin_: 1.5e18,
            leverageMax_: type(uint256).max
        });

        // Modifying the position to have margin as 0.05 ETH and additional size as 120 ETH
        // effectively creating a position with lesser margin than required for as liquidation margin.
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAdjustLeverage.selector,
                alice,
                tokenId,
                int256(-9.95e18) + int256(vaultProxy.getTradeFee(90e18)) + int256(mockKeeperFee.getKeeperFee()),
                90e18,
                0
            ),
            expectedErrorSignature: "PositionCreatesBadDebt()",
            ignoreErrorArguments: true
        });
    }

    function test_revert_adjust_position_when_minimum_margin_not_satisfied() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        vm.startPrank(admin);

        // Effectively remove the max leverage limit so that a position can be immediately liquidatable.
        // Immediately liquidatable due to liquidation buffer/margin provided being less than required
        // for the position size.
        // Also increase the minimum margin requirement to 0.075 ETH so that the min margin assertion check
        // in the adjust function fails.
        leverageModProxy.setLeverageCriteria({
            marginMin_: 0.75e18,
            leverageMin_: 1.5e18,
            leverageMax_: type(uint256).max
        });

        // Modifying the position to have margin as 0.05 ETH and additional size as 120 ETH
        // effectively creating a position with lesser margin than required for as liquidation margin.
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAdjustLeverage.selector,
                alice,
                tokenId,
                int256(-9.29e18) + int256(vaultProxy.getTradeFee(90e18)) + int256(mockKeeperFee.getKeeperFee()),
                90e18,
                0
            ),
            expectedErrorSignature: "MarginTooSmall(uint256,uint256)",
            errorData: abi.encodeWithSelector(LeverageModule.MarginTooSmall.selector, 0.75e18, 0.71e18)
        });
    }

    function test_revert_adjust_position_when_current_margin_not_enough_to_cover_fees() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // -10 ETH margin, -10 ETH in size
        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(
                OrderHelpers.announceAndExecuteLeverageAdjust.selector,
                tokenId,
                alice,
                keeper,
                -10e18,
                -10e18,
                collateralPrice,
                0
            ),
            expectedErrorSignature: "ValueNotPositive(string)",
            errorData: abi.encodeWithSelector(
                ICommonErrors.ValueNotPositive.selector,
                "newMarginAfterSettlement|newAdditionalSize"
            )
        });
    }

    /**
     * Price Increase Suites (8 Scenarios)
     */
    function test_adjust_position_margin_increase_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +5 ETH margin, no change in size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                15e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0
        });
    }

    function test_adjust_position_size_increase_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH size, no change in margin
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment = 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 0e18,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_increase_size_increase_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;

        // 100% increase
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH margin, +10 ETH size
        uint256 adjustmentTradeFee = announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        // Trade fee is taken from user during size adjustments when margin adjustment >= 0
        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                20e18 -
                adjustmentTradeFee,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_increase_size_decrease_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH margin, -10 ETH size
        uint256 adjustmentTradeFee = announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Trade fee is taken from user during size adjustments when margin adjustment >= 0
        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                20e18 -
                adjustmentTradeFee,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_position_margin_decrease_size_increase_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, +10 ETH size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_decrease_size_decrease_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, -10 ETH size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_position_margin_decrease_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, no change in size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 0,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 0
        });
    }

    function test_adjust_position_size_decrease_price_increase() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 2000e8;
        // 100% increase
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -10 ETH size, no change in margin
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment = 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 0,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_position_size_decrease_price_large_increase() public {
        vm.startPrank(admin);
        leverageModProxy.setLeverageCriteria({marginMin_: 0.05e18, leverageMin_: 1.2e18, leverageMax_: 25e18});

        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

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
            margin: 10e18,
            additionalSize: 20e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 newCollateralPrice = 3000e8;

        setCollateralPrice(newCollateralPrice);

        // Just ensures that there are no global parameter update issues
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });
    }

    /**
     * Price Decrease Suites (8 Scenarios)
     */

    function test_adjust_position_margin_increase_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +5 ETH margin, no change in size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Trade fee is not taken (0) when size is not adjusted
        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                15e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 5e18,
            additionalSizeAdjustment: 0
        });
    }

    function test_adjust_position_size_increase_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH size, no change in margin
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment = 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 0,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_increase_size_increase_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH margin, +10 ETH size
        uint256 adjustmentTradeFee = announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Trade fee is taken from user during size adjustments when margin adjustment >= 0
        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                20e18 -
                adjustmentTradeFee,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_increase_size_decrease_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        uint256 keeperFee2 = mockKeeperFee.getKeeperFee();

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // +10 ETH margin, -10 ETH size
        uint256 adjustmentTradeFee = announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: keeperFee2
        });

        // Trade fee is taken from user during size adjustments when margin adjustment >= 0
        assertEq(
            aliceCollateralBalanceBefore -
                keeperFee *
                2 -
                keeperFee2 -
                vaultProxy.getTradeFee(30e18) -
                stableDeposit -
                20e18 -
                adjustmentTradeFee,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 10e18,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_position_margin_decrease_size_increase_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 20 ETH size (3x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 20e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, +10 ETH size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(20e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 10e18
        });
    }

    function test_adjust_position_margin_decrease_size_decrease_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, -10 ETH size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_position_margin_decrease_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -1 ETH margin, no change in size
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 0,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment < 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - vaultProxy.getTradeFee(30e18) - stableDeposit - 10e18 + 1e18,
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: -1e18,
            additionalSizeAdjustment: 0
        });
    }

    function test_adjust_position_size_decrease_price_decrease() public {
        uint256 aliceCollateralBalanceBefore = collateralAsset.balanceOf(alice);
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

        // 10 ETH margin, 30 ETH size (4x)
        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 10e18,
            additionalSize: 30e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: keeperFee
        });

        uint256 newCollateralPrice = 800e8;
        setCollateralPrice(newCollateralPrice);

        PositionState memory stateBeforeAdjustment = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        // -10 ETH size, no change in margin
        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0,
            additionalSizeAdjustment: -10e18,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: mockKeeperFee.getKeeperFee()
        });

        // Trade fee is taken from existing margin during size adjustments when margin adjustment = 0
        assertEq(
            aliceCollateralBalanceBefore - keeperFee * 2 - stableDeposit - 10e18 - vaultProxy.getTradeFee(30e18),
            collateralAsset.balanceOf(alice),
            "Alice collateral balance incorrect"
        );

        PositionState memory stateAfterAdjustment = PositionState({
            collateralPrice: newCollateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        _adjustAssertions({
            beforeState: stateBeforeAdjustment,
            afterState: stateAfterAdjustment,
            marginAdjustment: 0,
            additionalSizeAdjustment: -10e18
        });
    }

    function test_adjust_price_recovery_margin() public {
        uint256 stableDeposit = 100e18;
        uint256 collateralPrice = 1000e8;

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
            margin: 60e18,
            additionalSize: 40e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 newCollateralPrice = 500e8;
        setCollateralPrice(newCollateralPrice);

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 1e15, // just a minor margin adjustment
            additionalSizeAdjustment: 0,
            oraclePrice: newCollateralPrice,
            keeperFeeAmount: 0
        });

        setCollateralPrice(collateralPrice);

        PositionState memory stateAfterPriceRecovery = PositionState({
            collateralPrice: collateralPrice,
            position: vaultProxy.getPosition(tokenId),
            positionSummary: leverageModProxy.getPositionSummary(tokenId),
            marketSummary: viewer.getMarketSummary(),
            globalPositions: vaultProxy.getGlobalPositions(),
            collateralPerShare: stableModProxy.stableCollateralPerShare()
        });

        assertEq(
            uint256(60e18), // initial margin
            uint256(stateAfterPriceRecovery.positionSummary.marginAfterSettlement - 1e15),
            "Margin is not correct after adjustment and price recovery"
        );
    }

    function _adjustAssertions(
        PositionState memory beforeState,
        PositionState memory afterState,
        int256 marginAdjustment,
        int256 additionalSizeAdjustment
    ) internal view {
        uint256 keeperFee = mockKeeperFee.getKeeperFee();
        uint256 tradeFee = vaultProxy.getTradeFee(
            additionalSizeAdjustment < 0 ? uint256(-additionalSizeAdjustment) : uint256(additionalSizeAdjustment)
        );
        uint256 protocolFee = (vaultProxy.protocolFeePercentage() * tradeFee) / 1e18;
        int256 settledPnL;

        if (additionalSizeAdjustment <= 0) {
            settledPnL =
                (-additionalSizeAdjustment *
                    (int256(afterState.collateralPrice) - int256(beforeState.collateralPrice))) /
                int256(afterState.collateralPrice);

            assertEq(
                beforeState.collateralPrice * 1e10,
                afterState.position.averagePrice,
                "Last price should not have changed because size adjustment has either dereased or unchanged"
            );
        } else {
            int256 expectedAveragePriceTimesTen = (((int256(beforeState.position.averagePrice) *
                int256(beforeState.position.additionalSize)) +
                (int256(afterState.collateralPrice) * 1e10 * additionalSizeAdjustment)) * 10) /
                (int256(beforeState.position.additionalSize) + additionalSizeAdjustment);

            assertEq(
                int256(afterState.position.averagePrice),
                (expectedAveragePriceTimesTen % 10 != 0)
                    ? expectedAveragePriceTimesTen / 10 + 1
                    : expectedAveragePriceTimesTen / 10,
                "Last price should be the average price because size adjustment has increased"
            );
        }

        if (marginAdjustment > 0) {
            assertEq(
                uint256(int256(beforeState.position.marginDeposited) + marginAdjustment + settledPnL),
                afterState.position.marginDeposited,
                "Margin deposited is not correct after adjustment"
            );

            assertEq(
                beforeState.positionSummary.marginAfterSettlement + marginAdjustment,
                afterState.positionSummary.marginAfterSettlement,
                "Margin after settlement is not correct after adjustment"
            );
            assertEq(
                beforeState.globalPositions.marginDepositedTotal + marginAdjustment + settledPnL,
                afterState.globalPositions.marginDepositedTotal,
                "Global margin deposited incorrect after adjustment"
            );
        } else {
            // Fees are taken from existing margin during size adjustments when margin adjustment <= 0
            assertEq(
                uint256(
                    int256(beforeState.position.marginDeposited) +
                        marginAdjustment +
                        settledPnL -
                        int256(keeperFee) -
                        int256(tradeFee)
                ),
                afterState.position.marginDeposited,
                "Margin deposited is not correct after adjustment"
            );
            assertEq(
                beforeState.positionSummary.marginAfterSettlement +
                    marginAdjustment -
                    int256(keeperFee) -
                    int256(tradeFee), // Trade fee is taken from existing margin during size adjustments when margin adjustment <= 0
                afterState.positionSummary.marginAfterSettlement,
                "Margin after settlement is not correct after adjustment"
            );
            assertEq(
                beforeState.globalPositions.marginDepositedTotal +
                    marginAdjustment +
                    settledPnL -
                    int256(keeperFee) -
                    int256(tradeFee),
                afterState.globalPositions.marginDepositedTotal,
                "Global margin deposited incorrect after adjustment"
            );
        }
        assertEq(
            int256(beforeState.position.additionalSize) + additionalSizeAdjustment,
            int256(afterState.position.additionalSize),
            "Size is not correct after adjustment"
        );
        assertEq(
            beforeState.positionSummary.profitLoss - settledPnL,
            afterState.positionSummary.profitLoss,
            "PnL should only have been partially settled after adjustment"
        );
        assertApproxEqAbs(
            beforeState.marketSummary.profitLossTotalByLongs,
            afterState.marketSummary.profitLossTotalByLongs + settledPnL,
            1,
            "Total PnL change incorrect after adjustment"
        );
        assertApproxEqAbs(
            beforeState.collateralPerShare + (((tradeFee - protocolFee) * 1e18) / stableModProxy.totalSupply()),
            afterState.collateralPerShare,
            1,
            "Collateral per share incorrect after adjustment"
        );
    }

    // Checks if transferring the keeper fee to the vault happens first before sending it to the keeper's address
    // and ensures that the transfer of the keeper fee will work under all circumstances.
    // This edge case might occur if there is low liquidity in the vault, a high keeper fee in the market, or a combination of both.
    // Thus, the implementation should not assume that there is always sufficient liquidity in the vault to pay the keeper in advance
    function test_adjust_position_when_not_sufficient_liquidity_in_vault() public {
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 0.1e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 0.1e18,
            additionalSize: 0.1e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageAdjust({
            tokenId: tokenId,
            traderAccount: alice,
            keeperAccount: keeper,
            marginAdjustment: 0.1e18,
            additionalSizeAdjustment: 0,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 1e18 // See the large keeper fee set
        });
    }

    function test_revert_adjust_position_when_position_underwater() public {
        uint256 collateralPrice = 1000e8;

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: 120e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId = announceAndExecuteLeverageOpen({
            traderAccount: alice,
            keeperAccount: keeper,
            margin: 50e18,
            additionalSize: 100e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: 20e18,
            additionalSize: 20e18,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // Set the new collateral price slightly above the liquidation price.
        // The announcement should be successful.
        uint256 liqPrice = viewer.liquidationPrice(tokenId);
        uint256 newCollateralPrice = (liqPrice + 2e10) / 1e10;

        setCollateralPrice(newCollateralPrice);

        LeverageModuleStructs.PositionSummary memory alicePositionSummary = leverageModProxy.getPositionSummary(
            tokenId
        );
        int256 settledMargin = alicePositionSummary.marginAfterSettlement;

        assertGt(settledMargin, 0, "Margin should be greater than 0 after settlement");

        vm.startPrank(alice);

        collateralAsset.approve(address(orderAnnouncementModProxy), 5e18);

        orderAnnouncementModProxy.announceLeverageAdjust({
            tokenId_: tokenId,
            marginAdjustment_: 3e18, // Top up margin such that the new margin is +ve and the position is not liquidatable.
            additionalSizeAdjustment_: -97e18,
            fillPrice_: liqPrice / 2,
            keeperFee_: mockKeeperFee.getKeeperFee()
        });

        skip(orderAnnouncementModProxy.minExecutabilityAge());

        // Set the collateral price $5 lower than the liquidation price.
        newCollateralPrice = (liqPrice / 1e10) - 5e8;

        setCollateralPrice(newCollateralPrice);

        LeverageModuleStructs.PositionSummary memory alicePositionSummaryAfter = leverageModProxy.getPositionSummary(
            tokenId
        );

        assertLt(alicePositionSummaryAfter.marginAfterSettlement, 0, "Margin should be less than 0 after settlement");

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeWithSelector(this.executeAdjustLeverage.selector, keeper, alice, newCollateralPrice),
            expectedErrorSignature: "ValueNotPositive(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ValueNotPositive.selector, "marginAfterSettlement")
        });
    }

    function test_revert_adjust_position_after_position_liquidated() public {
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

        announceAdjustLeverage({
            traderAccount: alice,
            tokenId: tokenId,
            marginAdjustment: 20e18,
            additionalSizeAdjustment: 0,
            keeperFeeAmount: 0
        });

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
