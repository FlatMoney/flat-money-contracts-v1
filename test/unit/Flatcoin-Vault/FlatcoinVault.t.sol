// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "../../helpers/Setup.sol";
import {ExpectRevert} from "../../helpers/ExpectRevert.sol";
import "../../helpers/OrderHelpers.sol";

contract FlatcoinVaultTest is OrderHelpers, ExpectRevert {
    function test_revert_when_caller_not_owner() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setLeverageTradingFee.selector, 0),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setSkewFractionMax.selector, 0),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setStableCollateralCap.selector, 0),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        FlatcoinVaultStructs.AuthorizedModule[] memory authorizedModules;
        FlatcoinVaultStructs.AuthorizedModule memory authorizedModule;

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.addAuthorizedModules.selector, authorizedModules),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.addAuthorizedModule.selector, authorizedModule),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        bytes32 moduleKey;

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.removeAuthorizedModule.selector, moduleKey),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.pauseModule.selector, moduleKey),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.unpauseModule.selector, moduleKey),
            expectedErrorSignature: "OwnableUnauthorizedAccount(address)",
            errorData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice)
        });
    }

    function test_revert_when_wrong_leverage_trading_fee_value() public {
        vm.startPrank(admin);

        // 100% fee
        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setLeverageTradingFee.selector, 1.1e18),
            expectedErrorSignature: "InvalidPercentageValue(uint64)",
            errorData: abi.encodeWithSelector(ICommonErrors.InvalidPercentageValue.selector, 1.1e18)
        });
    }

    function test_revert_when_caller_not_authorized_module() public {
        vm.startPrank(alice);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.sendCollateral.selector, alice, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.updateStableCollateralTotal.selector, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        LeverageModuleStructs.Position memory position;

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.setPosition.selector, position, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.deletePosition.selector, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.updateGlobalPositionData.selector, 0, 0, 0),
            expectedErrorSignature: "OnlyAuthorizedModule(address)",
            errorData: abi.encodeWithSelector(ICommonErrors.OnlyAuthorizedModule.selector, alice)
        });
    }

    function test_revert_when_wrong_module_params() public {
        vm.startPrank(admin);

        FlatcoinVaultStructs.AuthorizedModule memory module;

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.addAuthorizedModule.selector, module),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroAddress.selector, "moduleAddress")
        });

        module.moduleAddress = address(orderAnnouncementModProxy);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.addAuthorizedModule.selector, module),
            expectedErrorSignature: "ZeroValue(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroValue.selector, "moduleKey")
        });

        module.moduleKey = bytes32(uint256(1));
        module.moduleAddress = address(0);

        _expectRevertWithCustomError({
            target: address(vaultProxy),
            callData: abi.encodeWithSelector(vaultProxy.addAuthorizedModule.selector, module),
            expectedErrorSignature: "ZeroAddress(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ZeroAddress.selector, "moduleAddress")
        });
    }

    /// @dev Test for the scenario when the LPs lose their deposits due to sudden price rise.
    ///      The vault should revert updates when the `stableCollateralTotal` isn't enough to cover settled margins
    ///      of the leverage traders.
    function test_revert_when_LPs_lose_their_deposits_due_to_price_rise() public {
        uint256 stableDeposit = 100e18;
        uint256 skewFractionMax = vaultProxy.skewFractionMax();
        uint256 additionalSize = (stableDeposit * skewFractionMax) / 1e18; // Calculate the max additional size that can be used to open a position.
        uint256 margin = additionalSize; // Effectively creating a 2x leverage position.
        uint256 collateralPrice = 1000e8;

        setCollateralPrice(collateralPrice);

        announceAndExecuteDeposit({
            traderAccount: alice,
            keeperAccount: keeper,
            depositAmount: stableDeposit,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId1 = announceAndExecuteLeverageOpen({
            traderAccount: bob,
            keeperAccount: keeper,
            margin: margin / 2,
            additionalSize: additionalSize / 2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        uint256 tokenId2 = announceAndExecuteLeverageOpen({
            traderAccount: carol,
            keeperAccount: keeper,
            margin: margin / 2,
            additionalSize: additionalSize / 2,
            oraclePrice: collateralPrice,
            keeperFeeAmount: 0
        });

        // LPs lose their deposits when price rises by this multiple.
        // For example, if the `skewFractionMax` is 1.2 then price rise of 6x will cause LPs to lose their deposits.
        uint256 lpLiquidationPriceRiseMultiple = skewFractionMax / (skewFractionMax - 1e18);
        uint256 lpLiquidationPrice = collateralPrice * lpLiquidationPriceRiseMultiple + 10e8; // Adding a bit more to ensure fees and such factors are accounted for.

        setCollateralPrice(lpLiquidationPrice);

        announceAndExecuteLeverageClose({
            tokenId: tokenId1,
            traderAccount: bob,
            keeperAccount: keeper,
            oraclePrice: lpLiquidationPrice,
            keeperFeeAmount: 0
        });

        _expectRevertWithCustomError({
            target: address(this),
            callData: abi.encodeCall(
                this.announceAndExecuteLeverageClose,
                (tokenId2, carol, keeper, lpLiquidationPrice, 0)
            ),
            expectedErrorSignature: "ValueNotPositive(string)",
            errorData: abi.encodeWithSelector(ICommonErrors.ValueNotPositive.selector, "stableCollateralTotal")
        });
    }
}
