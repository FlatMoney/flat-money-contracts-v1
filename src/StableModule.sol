// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC20LockableUpgradeable} from "./abstracts/ERC20LockableUpgradeable.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {FeeManager} from "./abstracts/FeeManager.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";
import {IStableModule} from "./interfaces/IStableModule.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {IControllerModule} from "./interfaces/IControllerModule.sol";
import "./interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

/// @title StableModule
/// @author dHEDGE
/// @notice Contains functions to handle stable LP deposits and withdrawals.
/// @dev Shouldn't contain any collateral token amount.
contract StableModule is IStableModule, ModuleUpgradeable, ERC20LockableUpgradeable {
    using SafeCast for *;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event Deposit(address depositor, uint256 depositAmount, uint256 mintedAmount);
    event Withdraw(address withdrawer, uint256 withdrawAmount, uint256 burnedAmount, uint256 withdrawFee);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error PriceImpactDuringWithdraw();
    error PriceImpactDuringFullWithdraw();

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    /// @notice The minimum totalSupply that is mintable.
    uint32 public constant MIN_LIQUIDITY = 10_000; // minimum totalSupply that is allowable

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    function initialize(IFlatcoinVault vault_) external initializer {
        __Module_init(FlatcoinModuleKeys._STABLE_MODULE_KEY, vault_);
        __ERC20_init("Flat Money", "UNIT");
    }

    /////////////////////////////////////////////
    //       Authorized Module Functions       //
    /////////////////////////////////////////////

    /// @notice User delayed deposit into the stable LP. Mints ERC20 token receipt.
    /// @dev Needs to be used in conjunction with OrderExecution module.
    /// @param account_ The usser account which has a pending deposit.
    /// @param executableAtTime_ The time at which the order can be executed.
    /// @param announcedDeposit_ The pending order.
    function executeDeposit(
        address account_,
        uint64 executableAtTime_,
        DelayedOrderStructs.AnnouncedStableDeposit calldata announcedDeposit_
    ) external onlyAuthorizedModule {
        uint256 depositAmount = announcedDeposit_.depositAmount;

        uint32 maxAge = _getMaxAge(executableAtTime_);

        uint256 liquidityMinted = (depositAmount * (10 ** decimals())) /
            stableCollateralPerShare({maxAge_: maxAge, priceDiffCheck_: true});

        if (liquidityMinted < announcedDeposit_.minAmountOut)
            revert ICommonErrors.HighSlippage(liquidityMinted, announcedDeposit_.minAmountOut);

        _mint(account_, liquidityMinted);

        vault.updateStableCollateralTotal(int256(depositAmount));

        uint256 newTotalSupply = totalSupply();
        if (newTotalSupply < MIN_LIQUIDITY)
            revert ICommonErrors.AmountTooSmall({amount: newTotalSupply, minAmount: MIN_LIQUIDITY});

        emit Deposit(account_, depositAmount, liquidityMinted);
    }

    /// @notice User delayed withdrawal from the stable LP. Burns ERC20 token receipt.
    /// @dev Needs to be used in conjunction with OrderExecution module.
    /// @param account_ The usser account which has a pending withdrawal.
    /// @param executableAtTime_ The time at which the order can be executed.
    /// @param announcedWithdraw_ The pending order.
    /// @return amountOut_ The amount of collateral withdrawn.
    /// @return withdrawFee_ The fee paid to the remaining LPs.
    function executeWithdraw(
        address account_,
        uint64 executableAtTime_,
        DelayedOrderStructs.AnnouncedStableWithdraw calldata announcedWithdraw_
    ) external onlyAuthorizedModule returns (uint256 amountOut_, uint256 withdrawFee_) {
        uint256 withdrawAmount = announcedWithdraw_.withdrawAmount;

        uint32 maxAge = _getMaxAge(executableAtTime_);

        uint256 stableCollateralPerShareBefore = stableCollateralPerShare({maxAge_: maxAge, priceDiffCheck_: true});
        amountOut_ = (withdrawAmount * stableCollateralPerShareBefore) / (10 ** decimals());

        // Unlock the locked LP tokens before burning.
        // This is because if the amount to be burned is locked, the burn will fail due to `_beforeTokenTransfer`.
        _unlock(account_, withdrawAmount);

        _burn(account_, withdrawAmount);

        vault.updateStableCollateralTotal(-int256(amountOut_));

        uint256 stableCollateralPerShareAfter = stableCollateralPerShare({maxAge_: maxAge, priceDiffCheck_: true});

        // Check that there is no significant impact on stable token price.
        // This should never happen and means that too much value or not enough value was withdrawn.
        // Note that there is some overlap with InvariantChecks.stableCollateralPerShareIncreasesOrRemainsUnchanged
        if (totalSupply() > 0) {
            {
                uint256 absDiff;

                if (stableCollateralPerShareAfter > stableCollateralPerShareBefore) {
                    absDiff = stableCollateralPerShareAfter - stableCollateralPerShareBefore;
                } else {
                    absDiff = stableCollateralPerShareBefore - stableCollateralPerShareAfter;
                }
                uint256 percentDiff = (absDiff * 1e18) / stableCollateralPerShareBefore;

                if (percentDiff > 0.0001e16) {
                    revert PriceImpactDuringWithdraw();
                }
            }
            // Apply the withdraw fee if it's not the final withdrawal.
            withdrawFee_ = FeeManager(address(vault)).getWithdrawalFee(amountOut_);

            // additionalSkew = 0 because withdrawal was already processed above.
            vault.checkSkewMax({
                sizeChange: 0,
                stableCollateralChange: int256(withdrawFee_ - FeeManager(address(vault)).getProtocolFee(withdrawFee_))
            });
        } else {
            // Need to check there are no longs open before allowing full system withdrawal.
            uint256 sizeOpenedTotal = vault.getGlobalPositions().sizeOpenedTotal;

            if (sizeOpenedTotal != 0) revert ICommonErrors.MaxSkewReached(sizeOpenedTotal);
        }

        emit Withdraw(account_, amountOut_, withdrawAmount, withdrawFee_);
    }

    /// @notice Function to lock a certain amount of an account's LP tokens.
    /// @dev This function is used to lock LP tokens when an account announces a delayed order.
    /// @param account_ The account to lock the LP tokens from.
    /// @param amount_ The amount of LP tokens to lock.
    function lock(address account_, uint256 amount_) external onlyAuthorizedModule {
        _lock(account_, amount_);
    }

    /// @notice Function to unlock a certain amount of an account's LP tokens.
    /// @dev This function is used to unlock LP tokens when an account cancels a delayed order
    ///      or when an order is executed.
    /// @param account_ The account to unlock the LP tokens from.
    /// @param amount_ The amount of LP tokens to unlock.
    function unlock(address account_, uint256 amount_) external onlyAuthorizedModule {
        _unlock(account_, amount_);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Total collateral available for withdrawal.
    /// @dev Balance takes into account trader profit and loss and funding rate.
    /// @return stableCollateralBalance_ The total collateral available for withdrawal.
    function stableCollateralTotalAfterSettlement() public view returns (uint256 stableCollateralBalance_) {
        return stableCollateralTotalAfterSettlement({maxAge_: type(uint32).max, priceDiffCheck_: false});
    }

    /// @notice Function to calculate total stable side collateral after accounting for trader profit and loss and funding fees.
    /// @param maxAge_ The oldest price oracle timestamp that can be used. Set to 0 to ignore.
    /// @return stableCollateralBalance_ The total collateral available for withdrawal.
    function stableCollateralTotalAfterSettlement(
        uint32 maxAge_,
        bool priceDiffCheck_
    ) public view returns (uint256 stableCollateralBalance_) {
        // Assumption => pnlTotal = pnlLong + fundingAccruedLong
        // The assumption is based on the fact that stable LPs are the counterparty to leverage traders.
        // If the `pnlLong` is +ve that means the traders won and the LPs lost between the last funding rate update and now.
        // Similary if the `fundingAccruedLong` is +ve that means the market was skewed short-side.
        // When we combine these two terms, we get the total profit/loss of the leverage traders.
        // NOTE: This function if called after settlement returns only the PnL as funding has already been adjusted
        //      due to calling `_settleFundingFees()`. Although this still means `netTotal` includes the funding
        //      adjusted long PnL, it might not be clear to the reader of the code.
        int256 netTotal = IControllerModule(vault.moduleAddress(FlatcoinModuleKeys._CONTROLLER_MODULE_KEY))
            .fundingAdjustedLongPnLTotal({maxAge: maxAge_, priceDiffCheck: priceDiffCheck_});

        // The flatcoin LPs are the counterparty to the leverage traders.
        // So when the traders win, the flatcoin LPs lose and vice versa.
        // Therefore we subtract the leverage trader profits and add the losses
        int256 totalAfterSettlement = int256(vault.stableCollateralTotal()) - netTotal;

        if (totalAfterSettlement < 0) {
            stableCollateralBalance_ = 0;
        } else {
            stableCollateralBalance_ = uint256(totalAfterSettlement);
        }
    }

    /// @notice Function to calculate the collateral per share.
    /// @return collateralPerShare_ The collateral per share.
    function stableCollateralPerShare() public view returns (uint256 collateralPerShare_) {
        return stableCollateralPerShare({maxAge_: type(uint32).max, priceDiffCheck_: false});
    }

    /// @notice Function to calculate the collateral per share.
    /// @param maxAge_ The oldest price oracle timestamp that can be used.
    /// @return collateralPerShare_ The collateral per share.
    function stableCollateralPerShare(
        uint32 maxAge_,
        bool priceDiffCheck_
    ) public view returns (uint256 collateralPerShare_) {
        uint256 totalSupply = totalSupply();

        if (totalSupply > 0) {
            uint256 stableBalance = stableCollateralTotalAfterSettlement({
                maxAge_: maxAge_,
                priceDiffCheck_: priceDiffCheck_
            });
            collateralPerShare_ = (stableBalance * (10 ** decimals())) / totalSupply;
        } else {
            (uint256 collateralPrice, ) = IOracleModule(vault.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY))
                .getPrice({asset: address(vault.collateral()), maxAge: maxAge_, priceDiffCheck: priceDiffCheck_});

            // no shares have been minted yet
            collateralPerShare_ = 1e36 / collateralPrice;
        }
    }

    /// @notice Quoter function for getting the stable deposit amount out.
    /// @param depositAmount_ The amount of collateral to deposit.
    /// @return amountOut_ The amount of LP tokens minted.
    function stableDepositQuote(uint256 depositAmount_) public view returns (uint256 amountOut_) {
        return (depositAmount_ * (10 ** decimals())) / stableCollateralPerShare();
    }

    /// @notice Quoter function for getting the stable withdraw amount out.
    /// @param withdrawAmount_ The amount of LP tokens to withdraw.
    /// @return amountOut_ The amount of collateral withdrawn.
    function stableWithdrawQuote(
        uint256 withdrawAmount_
    ) public view returns (uint256 amountOut_, uint256 withdrawalFee_) {
        amountOut_ = (withdrawAmount_ * stableCollateralPerShare()) / (10 ** decimals());
        withdrawalFee_ = (amountOut_ * FeeManager(address(vault)).stableWithdrawFee()) / 1e18;

        // Take out the withdrawal fee
        amountOut_ -= withdrawalFee_;
    }

    /// @notice Function to get the locked amount of an account.
    /// @param account_ The account to get the locked amount for.
    /// @return amountLocked_ The amount of LP tokens locked.
    function getLockedAmount(address account_) public view returns (uint256 amountLocked_) {
        return _lockedAmount[account_];
    }

    /////////////////////////////////////////////
    //            Internal Functions           //
    /////////////////////////////////////////////

    /// @notice Returns the maximum age of the oracle price to be used.
    /// @param executableAtTime_ The time at which the order is executable.
    /// @return maxAge_ The maximum age of the oracle price to be used.
    function _getMaxAge(uint64 executableAtTime_) internal view returns (uint32 maxAge_) {
        return (block.timestamp - executableAtTime_).toUint32();
    }
}
