// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC721LockableEnumerableUpgradeable} from "./misc/ERC721LockableEnumerableUpgradeable.sol";

import {DecimalMath} from "./libraries/DecimalMath.sol";
import {PerpMath} from "./libraries/PerpMath.sol";
import {FlatcoinErrors} from "./libraries/FlatcoinErrors.sol";
import {FlatcoinStructs} from "./libraries/FlatcoinStructs.sol";
import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {FlatcoinEvents} from "./libraries/FlatcoinEvents.sol";
import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";

import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {IPointsModule} from "./interfaces/IPointsModule.sol";
import {ILimitOrder} from "./interfaces/ILimitOrder.sol";

/// @title LeverageModule
/// @author dHEDGE
/// @notice Contains functions to create/manage leverage positions.
/// @dev This module shouldn't hold any funds but can direct the vault to transfer funds.
contract LeverageModule is ILeverageModule, ModuleUpgradeable, ERC721LockableEnumerableUpgradeable {
    using SafeCast for *;
    using DecimalMath for uint256;

    /// @notice ERC721 token ID increment on mint.
    uint256 public tokenIdNext;

    /// @notice Charged for opening, adjusting or closing a position.
    /// @dev 1e18 = 100%
    uint256 public leverageTradingFee;

    /// @notice Leverage position criteria limits
    /// @notice A minimum margin limit adds a cost to create a position and ensures it can be liquidated at high leverage
    uint256 public marginMin;

    /// @notice Minimum leverage limit ensures that the position is valuable and adds long open interest
    uint256 public leverageMin;

    /// @notice Maximum leverage limit ensures that the position is safely liquidatable by keepers
    uint256 public leverageMax;

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    function initialize(
        IFlatcoinVault _vault,
        uint256 _levTradingFee,
        uint256 _marginMin,
        uint256 _leverageMin,
        uint256 _leverageMax
    ) external initializer {
        __Module_init(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY, _vault);
        __ERC721_init("Flat Money Leveraged Positions", "LEV");

        setLeverageTradingFee(_levTradingFee);
        setLeverageCriteria(_marginMin, _leverageMin, _leverageMax);
    }

    /////////////////////////////////////////////
    //         External Write Functions         //
    /////////////////////////////////////////////

    /// @notice Leverage open function. Mints ERC721 token receipt.
    /// @dev Has to be used in conjunction with the DelayedOrder module.
    /// @dev Uses the Pyth network price to execute.
    /// @param _account The user account which has a pending open leverage order.
    /// @param _keeper The address of the keeper executing the order.
    /// @param _order The order to be executed.
    function executeOpen(
        address _account,
        address _keeper,
        FlatcoinStructs.Order calldata _order
    ) external onlyAuthorizedModule {
        // Make sure the oracle price is after the order executability time
        uint32 maxAge = _getMaxAge(_order.executableAtTime);

        FlatcoinStructs.AnnouncedLeverageOpen memory announcedOpen = abi.decode(
            _order.orderData,
            (FlatcoinStructs.AnnouncedLeverageOpen)
        );

        // Check that buy price doesn't exceed requested price.
        (uint256 entryPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            maxAge: maxAge,
            priceDiffCheck: true
        });

        if (entryPrice > announcedOpen.maxFillPrice)
            revert FlatcoinErrors.HighSlippage(entryPrice, announcedOpen.maxFillPrice);

        vault.checkSkewMax({
            sizeChange: announcedOpen.additionalSize,
            stableCollateralChange: int256(announcedOpen.tradeFee)
        });

        uint256 newTokenId;

        {
            // The margin change is equal to funding fees accrued to longs and the margin deposited by the trader.
            vault.updateGlobalPositionData({
                price: entryPrice,
                marginDelta: int256(announcedOpen.margin),
                additionalSizeDelta: int256(announcedOpen.additionalSize)
            });

            newTokenId = _mint(_account);

            vault.setPosition(
                FlatcoinStructs.Position({
                    averagePrice: entryPrice,
                    marginDeposited: announcedOpen.margin,
                    additionalSize: announcedOpen.additionalSize,
                    entryCumulativeFunding: vault.cumulativeFundingRate()
                }),
                newTokenId
            );
        }

        // Check that the new position isn't immediately liquidatable.
        if (
            ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)).canLiquidate(newTokenId)
        ) revert FlatcoinErrors.PositionCreatesBadDebt();

        // Mint points
        IPointsModule pointsModule = IPointsModule(vault.moduleAddress(FlatcoinModuleKeys._POINTS_MODULE_KEY));
        pointsModule.mintLeverageOpen(_account, announcedOpen.additionalSize);

        // Settle the collateral
        vault.updateStableCollateralTotal(int256(announcedOpen.tradeFee)); // pay the trade fee to stable LPs
        vault.sendCollateral({to: _keeper, amount: _order.keeperFee}); // pay the keeper their fee

        emit FlatcoinEvents.LeverageOpen(_account, newTokenId, entryPrice);
    }

    /// @notice Leverage adjust function.
    /// @dev Needs to be used in conjunction with the DelayedOrder module.
    /// @dev Note that a check has to be made in the calling module to ensure that
    ///      the position exists before calling this function.
    /// @param _account The user account which has a pending adjust leverage order.
    /// @param _keeper The address of the keeper executing the order.
    /// @param _order The order to be executed.
    function executeAdjust(
        address _account,
        address _keeper,
        FlatcoinStructs.Order calldata _order
    ) external onlyAuthorizedModule {
        uint32 maxAge = _getMaxAge(_order.executableAtTime);

        FlatcoinStructs.AnnouncedLeverageAdjust memory announcedAdjust = abi.decode(
            _order.orderData,
            (FlatcoinStructs.AnnouncedLeverageAdjust)
        );

        FlatcoinStructs.Position memory position = vault.getPosition(announcedAdjust.tokenId);

        (uint256 adjustPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            maxAge: maxAge,
            priceDiffCheck: true
        });

        int256 cumulativeFunding = vault.cumulativeFundingRate();

        // Prevent adjustment if the position is underwater.
        if (
            PerpMath
                ._getPositionSummary({position: position, nextFundingEntry: cumulativeFunding, price: adjustPrice})
                .marginAfterSettlement <= 0
        ) revert FlatcoinErrors.ValueNotPositive("marginAfterSettlement");

        // Fees come out from the margin if the margin is being reduced or remains unchanged (meaning the size is being modified).
        int256 marginAdjustment = (announcedAdjust.marginAdjustment > 0)
            ? announcedAdjust.marginAdjustment
            : announcedAdjust.marginAdjustment - int256(announcedAdjust.totalFee);

        // This accounts for the profit loss and funding fees accrued till now.
        int256 newMargin = marginAdjustment + int256(position.marginDeposited);

        uint256 newAdditionalSize = (int256(position.additionalSize) + announcedAdjust.additionalSizeAdjustment)
            .toUint256();

        uint256 newEntryPrice;

        if (announcedAdjust.additionalSizeAdjustment >= 0) {
            // Size is being increased. Adjust the entry price to the average entry price.

            if (adjustPrice > announcedAdjust.fillPrice)
                revert FlatcoinErrors.HighSlippage(adjustPrice, announcedAdjust.fillPrice);

            newEntryPrice =
                (position.averagePrice *
                    position.additionalSize +
                    adjustPrice *
                    uint256(announcedAdjust.additionalSizeAdjustment)) /
                newAdditionalSize;

            // Given that the size of a position is being increased, it's necessary to check that
            // it doesn't exceed the max skew limit.
            vault.checkSkewMax({
                sizeChange: uint256(announcedAdjust.additionalSizeAdjustment),
                stableCollateralChange: int256(announcedAdjust.tradeFee)
            });
        } else {
            // Size is being decreased. Keep the same entry price.

            if (adjustPrice < announcedAdjust.fillPrice)
                revert FlatcoinErrors.HighSlippage(adjustPrice, announcedAdjust.fillPrice);

            int256 partialPnLEarned = (-announcedAdjust.additionalSizeAdjustment *
                (int256(adjustPrice) - int256(position.averagePrice))) / int256(adjustPrice);

            newMargin += partialPnLEarned;
            newEntryPrice = position.averagePrice;

            // The margin being updated in the global position should also account for the pnl being settled for
            // partial closure of the position.
            marginAdjustment += partialPnLEarned;

            // Since position size decrease is akin to partial closure of the position, we have to settle the profit loss
            // associated with this position size. The settlement involves increasing/decreasing the stable collateral total
            // as LPs are the counterparty to each leverage position.
            vault.updateStableCollateralTotal(-partialPnLEarned);
        }

        // Entry cumulative funding is adjusted to account for the new size.
        // So that the position accumulated funding is not affected after adjustment.
        int256 newEntryCumulativeFunding = position.entryCumulativeFunding +
            (((cumulativeFunding - position.entryCumulativeFunding) * announcedAdjust.additionalSizeAdjustment) /
                int256(newAdditionalSize));

        // Check that the leverage isn't too high.
        checkLeverageCriteria(newMargin.toUint256(), newAdditionalSize);

        vault.updateGlobalPositionData({
            price: (announcedAdjust.additionalSizeAdjustment < 0) ? position.averagePrice : adjustPrice,
            marginDelta: marginAdjustment,
            additionalSizeDelta: announcedAdjust.additionalSizeAdjustment
        });

        vault.setPosition(
            FlatcoinStructs.Position({
                averagePrice: newEntryPrice,
                marginDeposited: newMargin.toUint256(),
                additionalSize: newAdditionalSize,
                entryCumulativeFunding: newEntryCumulativeFunding
            }),
            announcedAdjust.tokenId
        );

        // Check that the new position isn't immediately liquidatable.
        if (
            ILiquidationModule(vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)).canLiquidate(
                announcedAdjust.tokenId,
                adjustPrice
            )
        ) revert FlatcoinErrors.PositionCreatesBadDebt();

        // Mint points.
        if (announcedAdjust.additionalSizeAdjustment > 0) {
            address positionOwner = ownerOf(announcedAdjust.tokenId);
            IPointsModule pointsModule = IPointsModule(vault.moduleAddress(FlatcoinModuleKeys._POINTS_MODULE_KEY));

            pointsModule.mintLeverageOpen(positionOwner, uint256(announcedAdjust.additionalSizeAdjustment));
        }

        if (announcedAdjust.tradeFee > 0) vault.updateStableCollateralTotal(int256(announcedAdjust.tradeFee));

        // Sending keeper fee from order contract to the executor.
        vault.sendCollateral({to: _keeper, amount: _order.keeperFee});

        if (announcedAdjust.marginAdjustment < 0) {
            // We send the user that much margin they requested during announceLeverageAdjust().
            // However their remaining margin is reduced by the fees.
            // It is accounted in announceLeverageAdjust().
            uint256 marginToWithdraw = uint256(announcedAdjust.marginAdjustment * -1);

            // Withdrawing margin from the vault and sending it to the user.
            vault.sendCollateral({to: _account, amount: marginToWithdraw});
        }

        emit FlatcoinEvents.LeverageAdjust(announcedAdjust.tokenId, newEntryPrice, adjustPrice);
    }

    /// @notice Leverage close function.
    /// @dev Needs to be used in conjunction with the DelayedOrder module.
    /// @dev Note that a check has to be made in the calling module to ensure that
    ///      the position exists before calling this function.
    /// @param _account The user account which has a pending close leverage order.
    /// @param _keeper The address of the keeper executing the order.
    /// @param _order The order to be executed.
    function executeClose(
        address _account,
        address _keeper,
        FlatcoinStructs.Order calldata _order
    ) external onlyAuthorizedModule {
        FlatcoinStructs.AnnouncedLeverageClose memory announcedClose = abi.decode(
            _order.orderData,
            (FlatcoinStructs.AnnouncedLeverageClose)
        );

        FlatcoinStructs.Position memory position = vault.getPosition(announcedClose.tokenId);

        // Make sure the oracle price is after the order executability time
        uint32 maxAge = _getMaxAge(_order.executableAtTime);

        // check that sell price doesn't exceed requested price
        (uint256 exitPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            maxAge: maxAge,
            priceDiffCheck: true
        });
        if (exitPrice < announcedClose.minFillPrice)
            revert FlatcoinErrors.HighSlippage(exitPrice, announcedClose.minFillPrice);

        uint256 totalFee;
        int256 settledMargin;
        FlatcoinStructs.PositionSummary memory positionSummary;
        {
            positionSummary = PerpMath._getPositionSummary(position, vault.cumulativeFundingRate(), exitPrice);

            settledMargin = positionSummary.marginAfterSettlement;
            totalFee = announcedClose.tradeFee + _order.keeperFee;

            if (settledMargin <= 0) revert FlatcoinErrors.ValueNotPositive("settledMargin");
            // Make sure there is enough margin in the position to pay the keeper fee
            if (settledMargin < int256(totalFee)) revert FlatcoinErrors.NotEnoughMarginForFees(settledMargin, totalFee);

            vault.updateStableCollateralTotal(int256(announcedClose.tradeFee) - positionSummary.profitLoss); // pay the trade fee to stable LPs

            vault.updateGlobalPositionData({
                price: position.averagePrice,
                marginDelta: -(int256(position.marginDeposited) + positionSummary.accruedFunding),
                additionalSizeDelta: -int256(position.additionalSize)
            });

            // Delete position storage
            vault.deletePosition(announcedClose.tokenId);
        }

        // Cancel any existing limit order on the position
        ILimitOrder(vault.moduleAddress(FlatcoinModuleKeys._LIMIT_ORDER_KEY)).cancelExistingLimitOrder(
            announcedClose.tokenId
        );

        burn(announcedClose.tokenId, FlatcoinModuleKeys._LEVERAGE_MODULE_KEY);

        // Settle the collateral.
        vault.sendCollateral({to: _keeper, amount: _order.keeperFee}); // pay the keeper their fee
        vault.sendCollateral({to: _account, amount: uint256(settledMargin) - totalFee}); // transfer remaining amount to the trader

        emit FlatcoinEvents.LeverageClose(announcedClose.tokenId, exitPrice, positionSummary);
    }

    /// @notice Burns the ERC721 token representing the leverage position.
    /// @dev This function unlocks the position before burning it.
    ///      This is to avoid the transfer to address(0) reversion.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @param _moduleKey The module key which is burning the token.
    function burn(uint256 _tokenId, bytes32 _moduleKey) public onlyAuthorizedModule {
        _clearAllLocks(_tokenId, _moduleKey);
        _burn(_tokenId);
    }

    /// @notice Locks the ERC721 token representing the leverage position.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @param _moduleKey The module key which is locking the token.
    function lock(uint256 _tokenId, bytes32 _moduleKey) public onlyAuthorizedModule {
        _lock(_tokenId, _moduleKey);
    }

    /// @notice Unlocks the ERC721 token representing the leverage position.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @param _moduleKey The module key which is unlocking the token.
    function unlock(uint256 _tokenId, bytes32 _moduleKey) public onlyAuthorizedModule {
        _unlock(_tokenId, _moduleKey);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Returns the lock status of a leverage NFT position.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @return _lockStatus The lock status of the leverage position.
    function isLocked(uint256 _tokenId) public view override returns (bool _lockStatus) {
        return _lockCounter[_tokenId].lockCount > 0;
    }

    /// @notice Returns the lock status of a leverage NFT position by a module.
    /// @dev Note that when a position NFT is burned, the individual locks are not cleared.
    ///      Meaning, the lock count is set to 0 but individual lockedByModule statuses are not cleared.
    ///      So when lockedByModule is true but lock owner is address(0) then it means the position was deleted.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @param _moduleKey The module key to check if a module locked the NFT previously or not.
    /// @return _lockedByModuleStatus The lock status of the leverage position by the module.
    function isLockedByModule(
        uint256 _tokenId,
        bytes32 _moduleKey
    ) public view override returns (bool _lockedByModuleStatus) {
        return _lockCounter[_tokenId].lockedByModule[_moduleKey] && _ownerOf(_tokenId) != address(0);
    }

    /// @notice Returns a summary of a leverage position.
    /// @param _tokenId The ERC721 token ID of the leverage position.
    /// @return _positionSummary The summary of the leverage position.
    function getPositionSummary(
        uint256 _tokenId
    ) public view returns (FlatcoinStructs.PositionSummary memory _positionSummary) {
        FlatcoinStructs.Position memory position = vault.getPosition(_tokenId);
        FlatcoinStructs.VaultSummary memory vaultSummary = vault.getVaultSummary();

        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        // Get the nextFundingEntry for the market.
        int256 nextFundingEntry = PerpMath._nextFundingEntry(
            vaultSummary,
            vault.maxFundingVelocity(),
            vault.maxVelocitySkew()
        );

        return PerpMath._getPositionSummary(position, nextFundingEntry, currentPrice);
    }

    /// @notice Returns a summary of the market.
    /// @dev This includes all the parameters which are related mostly with the leverage traders.
    /// @return _marketSummary The summary of the market.
    function getMarketSummary() public view returns (FlatcoinStructs.MarketSummary memory _marketSummary) {
        FlatcoinStructs.VaultSummary memory vaultSummary = vault.getVaultSummary();

        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice();

        return
            PerpMath._getMarketSummaryLongs(
                vaultSummary,
                vault.maxFundingVelocity(),
                vault.maxVelocitySkew(),
                currentPrice
            );
    }

    /// @notice Returns the total profit and loss of all the leverage positions.
    /// @dev Adjusts for the funding fees accrued.
    /// @return _fundingAdjustedPnL The total profit and loss of all the leverage positions.
    function fundingAdjustedLongPnLTotal() public view returns (int256 _fundingAdjustedPnL) {
        return fundingAdjustedLongPnLTotal({_maxAge: type(uint32).max, _priceDiffCheck: false});
    }

    /// @notice Returns the total profit and loss of all the leverage positions.
    /// @dev Adjusts for the funding fees accrued.
    /// @param _maxAge The maximum age of the oracle price to be used.
    /// @return _fundingAdjustedPnL The total profit and loss of all the leverage positions.
    function fundingAdjustedLongPnLTotal(
        uint32 _maxAge,
        bool _priceDiffCheck
    ) public view returns (int256 _fundingAdjustedPnL) {
        (uint256 currentPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).getPrice({
            maxAge: _maxAge,
            priceDiffCheck: _priceDiffCheck
        });

        FlatcoinStructs.VaultSummary memory vaultSummary = vault.getVaultSummary();
        FlatcoinStructs.MarketSummary memory marketSummary = PerpMath._getMarketSummaryLongs(
            vaultSummary,
            vault.maxFundingVelocity(),
            vault.maxVelocitySkew(),
            currentPrice
        );

        return marketSummary.profitLossTotalByLongs + marketSummary.accruedFundingTotalByLongs;
    }

    /// @notice Asserts that the position to be opened meets margin and size criteria.
    /// @param _margin The margin to be deposited.
    /// @param _size The size of the position.
    function checkLeverageCriteria(uint256 _margin, uint256 _size) public view {
        uint256 leverage = ((_margin + _size) * 1e18) / _margin;

        if (leverage < leverageMin) revert FlatcoinErrors.LeverageTooLow(leverageMin, leverage);
        if (leverage > leverageMax) revert FlatcoinErrors.LeverageTooHigh(leverageMax, leverage);
        if (_margin < marginMin) revert FlatcoinErrors.MarginTooSmall(marginMin, _margin);
    }

    /// @notice Returns the trade fee for a given size.
    /// @param _size The size of the trade.
    /// @return _tradeFee The trade fee.
    function getTradeFee(uint256 _size) external view returns (uint256 _tradeFee) {
        return leverageTradingFee._multiplyDecimal(_size);
    }

    /////////////////////////////////////////////
    //       Internal/Private Functions        //
    /////////////////////////////////////////////

    /// @notice Handles incrementing the tokenIdNext and minting the nft
    /// @param _to the minter's address
    /// @return _tokenId the tokenId of the new NFT.
    function _mint(address _to) internal returns (uint256 _tokenId) {
        _tokenId = tokenIdNext;

        _safeMint(_to, tokenIdNext);

        tokenIdNext += 1;
    }

    /// @notice Returns the maximum age of the oracle price to be used.
    /// @param _executableAtTime The time at which the order is executable.
    /// @return _maxAge The maximum age of the oracle price to be used.
    function _getMaxAge(uint64 _executableAtTime) internal view returns (uint32 _maxAge) {
        return (block.timestamp - _executableAtTime).toUint32();
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Setter for the leverage open/close fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param _leverageTradingFee The new leverage trading fee.
    function setLeverageTradingFee(uint256 _leverageTradingFee) public onlyOwner {
        // Set fee cap to max 1%.
        // This is to avoid fat fingering but if any change is needed, the owner needs to
        // upgrade this module.
        if (_leverageTradingFee > 0.01e18) revert FlatcoinErrors.InvalidFee(_leverageTradingFee);

        leverageTradingFee = _leverageTradingFee;
    }

    /// @notice Setter for the leverage position criteria limits.
    /// @dev The limits are used to ensure that the position is valuable and there is an incentive to liquidate it.
    /// @param _marginMin The new minimum margin limit.
    /// @param _leverageMin The new minimum leverage limit.
    /// @param _leverageMax The new maximum leverage limit.
    function setLeverageCriteria(uint256 _marginMin, uint256 _leverageMin, uint256 _leverageMax) public onlyOwner {
        if (_leverageMax <= _leverageMin) revert FlatcoinErrors.InvalidLeverageCriteria();

        marginMin = _marginMin;
        leverageMin = _leverageMin;
        leverageMax = _leverageMax;
    }
}
