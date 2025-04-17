// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {ILeverageModule} from "./interfaces/ILeverageModule.sol";
import {IOrderAnnouncementModule} from "./interfaces/IOrderAnnouncementModule.sol";
import {ILiquidationModule} from "./interfaces/ILiquidationModule.sol";
import {IPositionSplitterModule} from "./interfaces/IPositionSplitterModule.sol";

import "./interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;
import "./interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

/// @title PositionSplitterModule
/// @author dHEDGE
/// @notice This module allows splitting of a position into multiple positions synchronously.
contract PositionSplitterModule is IPositionSplitterModule, ModuleUpgradeable {
    ///////////////////////////////
    //          Events           //
    ///////////////////////////////

    event PositionSplit(uint256 indexed positionId, uint256 newPosition);

    ///////////////////////////////
    //          Errors           //
    ///////////////////////////////

    error OnlyPositionOwner(address currentOwner);
    error PositionLocked(uint256 tokenId);
    error PrimaryPositionLiquidatable(uint256 tokenId);
    error NewPositionLiquidatable(uint256 index);

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the PositionSplitterModule with the vault address.
    /// @param vault_ The address of the vault.
    function initialize(IFlatcoinVault vault_) external initializer {
        __Module_init(FlatcoinModuleKeys._POSITION_SPLITTER_MODULE_KEY, vault_);
    }

    ///////////////////////////////
    //       Split Functions     //
    ///////////////////////////////

    /// @notice Function to split a position into 2 given the position fraction.
    /// @dev For example, if the position has a margin of 100 and the position fraction is 0.5e18 (1/2) then the new position
    ///      will have 50% of the margin (techincally marginAfterSettlement) of the original position.
    /// @dev Note that splitting a position is not an option to reduce trade fees which is incurred
    ///      when a position is adjusted/closed.
    /// @dev Note that the liquidation price of both the positions may increase. Usually the smaller position will have a worse liquidation price.
    ///      When splitting a position, check that you account for this otherwise the positions might get liquidated.
    /// @param tokenId_ The token ID of the position to split.
    /// @param positionFraction_ The fraction of the position to split (1e18 is 100%).
    /// @param owner_ The address of the owner of the new position.
    /// @return newPositionId_ The token ID of the new position.
    function split(
        uint256 tokenId_,
        uint64 positionFraction_,
        address owner_
    ) external whenNotPaused returns (uint256 newPositionId_) {
        ILeverageModule leverageModule = ILeverageModule(vault.moduleAddress(FlatcoinModuleKeys._LEVERAGE_MODULE_KEY));
        ILiquidationModule liquidationModule = ILiquidationModule(
            vault.moduleAddress(FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY)
        );

        // Pre split checks.
        {
            address currentOwner = leverageModule.ownerOf(tokenId_);

            // Check that the caller is the owner of the position.
            if (msg.sender != currentOwner) {
                revert OnlyPositionOwner(currentOwner);
            }

            IOrderAnnouncementModule orderAnnouncementModule = IOrderAnnouncementModule(
                vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY)
            );

            DelayedOrderStructs.Order memory normalOrder = orderAnnouncementModule.getAnnouncedOrder(currentOwner);
            DelayedOrderStructs.Order memory limitOrder = orderAnnouncementModule.getLimitOrder(tokenId_);

            // If a normal order (leverage adjust/close) exists, disallow the transfer.
            if (normalOrder.orderType != DelayedOrderStructs.OrderType.None) {
                revert ICommonErrors.OrderExists(normalOrder.orderType);
            }

            // If a limit order exists, disallow the transfer.
            if (limitOrder.orderType != DelayedOrderStructs.OrderType.None) {
                revert ICommonErrors.OrderExists(limitOrder.orderType);
            }

            // Check that the position is not liquidatable.
            if (liquidationModule.canLiquidate(tokenId_)) {
                revert PrimaryPositionLiquidatable(tokenId_);
            }
        }

        LeverageModuleStructs.Position memory primaryPosition = vault.getPosition(tokenId_);
        uint256 leverageRatio = ((primaryPosition.additionalSize + primaryPosition.marginDeposited) * 1e18) /
            primaryPosition.marginDeposited;
        uint256 newPositionMargin = (vault.getPosition(tokenId_).marginDeposited * positionFraction_) / 1e18;
        uint256 newPositionSize = ((leverageRatio - 1e18) * newPositionMargin) / 1e18;

        // Primary position modifications.
        {
            uint256 primarySize = primaryPosition.additionalSize - newPositionSize;
            uint256 primaryMargin = primaryPosition.marginDeposited - newPositionMargin;

            // One can split a position in such a way that the primary position doesn't satisfy the leverage criteria.
            // Check that the primary position is still acceptable.
            leverageModule.checkLeverageCriteria(primaryMargin, primarySize);

            // Update the primary position.
            vault.setPosition(
                LeverageModuleStructs.Position({
                    averagePrice: primaryPosition.averagePrice,
                    marginDeposited: primaryMargin,
                    additionalSize: primarySize,
                    entryCumulativeFunding: primaryPosition.entryCumulativeFunding
                }),
                tokenId_
            );

            // Check that the primary position after split is not liquidatable.
            if (liquidationModule.canLiquidate(tokenId_)) {
                revert PrimaryPositionLiquidatable(tokenId_);
            }
        }

        // New position creation.
        {
            // Check that the new position is acceptable.
            // In other words, can it be created independently?
            leverageModule.checkLeverageCriteria(newPositionMargin, newPositionSize);

            // Mint the new position and set the same in the vault.
            newPositionId_ = leverageModule.mint(owner_);

            vault.setPosition(
                LeverageModuleStructs.Position({
                    averagePrice: primaryPosition.averagePrice,
                    marginDeposited: newPositionMargin,
                    additionalSize: newPositionSize,
                    entryCumulativeFunding: primaryPosition.entryCumulativeFunding
                }),
                newPositionId_
            );

            if (liquidationModule.canLiquidate(newPositionId_)) revert NewPositionLiquidatable(newPositionId_);
        }

        emit PositionSplit(tokenId_, newPositionId_);
    }
}
