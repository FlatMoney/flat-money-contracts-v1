// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {FlatcoinModuleKeys} from "../../libraries/FlatcoinModuleKeys.sol";

import {FeeManager} from "../../abstracts/FeeManager.sol";

import "../../libraries/SwapperStructs.sol" as SwapperStructs;
import "../../interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;

import {IFlatcoinVault} from "../../interfaces/IFlatcoinVault.sol";
import {IOrderAnnouncementModule} from "../../interfaces/IOrderAnnouncementModule.sol";
import {ISwapper} from "../../interfaces/ISwapper.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

import {TokenTransferMethods} from "../Swapper/TokenTransferMethods.sol";
import {FlatZapperStorage} from "./FlatZapperStorage.sol";

/// @title FlatZapper
/// @author dHEDGE
/// @notice Contract to swap tokens to the collateral token and announce an order to the Flat Money Protocol.
/// @dev Follows the new ERC7201 storage pattern.
contract FlatZapper is FlatZapperStorage, OwnableUpgradeable, TokenTransferMethods {
    using SafeERC20 for IERC20;

    //////////////////////////
    //        Events        //
    //////////////////////////

    event ZapCompleted(address indexed sender, DelayedOrderStructs.OrderType indexed orderType);

    //////////////////////////
    //        Errors        //
    //////////////////////////

    error InvalidOrderType();
    error ZeroAddress(string variableName);
    error AmountReceivedForMarginTooSmall(uint256 receivedAmount, uint256 minMargin);
    error NotEnoughCollateralAfterFees(uint256 collateralReceived, uint256 fees);

    /////////////////////////
    //       Structs       //
    /////////////////////////

    struct DepositData {
        uint256 minAmountOut;
        uint256 keeperFee;
    }

    /// @dev Note that if a user doesn't want a limit order to be placed, they can set the `stopLossPrice` and `profitTakePrice`
    ///      as `0` and `type(uint256).max` respectively.
    struct LeverageOpenData {
        uint256 minMargin;
        uint256 additionalSize;
        uint256 maxFillPrice;
        uint256 stopLossPrice;
        uint256 profitTakePrice;
        uint256 keeperFee;
    }

    struct AnnouncementData {
        DelayedOrderStructs.OrderType orderType;
        bytes data;
    }

    //////////////////////////
    //       Functions      //
    //////////////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        IFlatcoinVault vault_,
        IERC20 collateral_,
        ISwapper swapper_,
        address orderAnnouncementModule_,
        address permit2_,
        IWETH wrappedNativeToken_
    ) external initializer {
        __Ownable_init(owner_);

        if (address(vault_) == address(0) || address(collateral_) == address(0) || address(swapper_) == address(0))
            revert ZeroAddress("vault|collateral|swapper");

        __FlatZapperStorage_init({vault_: vault_, collateral_: collateral_, swapper_: swapper_});

        __TokenTransferMethods_init(permit2_, wrappedNativeToken_);

        // Approve the order announcement module to spend `collateral_`.
        // As this contract won't hold any `collateral_` for a significant time, we can approve it to spend an unlimited amount.
        _unlimitedApprove(collateral_, orderAnnouncementModule_);
    }

    /// @notice Zaps into the Flat Money Protocol.
    /// @dev This function is used to swap the source token to the collateral token and announce an order to the Flat Money Protocol.
    /// @dev The `srcData` in the `swapStruct_` should contain the data required to transfer the source token(s) to this contract.
    ///      and not to the Swapper contract.
    /// @param swapStruct_ The data required to swap the source token(s) to the collateral token(s).
    /// @param announcementData_ The data required to announce the order to the Flat Money Protocol.
    function zap(
        SwapperStructs.InOutData calldata swapStruct_,
        AnnouncementData calldata announcementData_
    ) external payable {
        IERC20 collateral = getCollateral();

        uint256 collateralBalanceBefore = collateral.balanceOf(address(this));

        _transferFromCaller(msg.sender, swapStruct_.srcData);
        _swap(swapStruct_);

        uint256 collateralReceived = collateral.balanceOf(address(this)) - collateralBalanceBefore;

        _createOrder(announcementData_, collateralReceived);

        emit ZapCompleted({sender: msg.sender, orderType: announcementData_.orderType});
    }

    function _swap(SwapperStructs.InOutData memory swapStruct_) internal {
        ISwapper swapper = getSwapper();

        uint256 numSrcTokens;
        for (uint256 i; i < swapStruct_.srcData.length; ++i) {
            numSrcTokens += swapStruct_.srcData[i].srcTokenSwapDetails.length;
        }

        // We only require a single element in the array as we are only going to use the
        // simple allowance transfer method to transfer `srcTokens` from this contract to
        // the swapper.
        SwapperStructs.SrcData[] memory newSrcData = new SwapperStructs.SrcData[](1);
        newSrcData[0].srcTokenSwapDetails = new SwapperStructs.SrcTokenSwapDetails[](numSrcTokens);

        // Although not required to be set explicitly, we are setting the transfer method to `ALLOWANCE`.
        newSrcData[0].transferMethodData.method = SwapperStructs.TransferMethod.ALLOWANCE;

        uint256 srcTokenIndex;
        for (uint256 i; i < swapStruct_.srcData.length; ++i) {
            for (uint256 j; j < swapStruct_.srcData[i].srcTokenSwapDetails.length; ++j) {
                newSrcData[0].srcTokenSwapDetails[srcTokenIndex++] = SwapperStructs.SrcTokenSwapDetails({
                    token: swapStruct_.srcData[i].srcTokenSwapDetails[j].token,
                    amount: swapStruct_.srcData[i].srcTokenSwapDetails[j].amount,
                    aggregatorData: swapStruct_.srcData[i].srcTokenSwapDetails[j].aggregatorData
                });

                // Max approve the Swapper to spend the source token.
                _unlimitedApprove(swapStruct_.srcData[i].srcTokenSwapDetails[j].token, address(swapper));
            }
        }

        swapStruct_.srcData = newSrcData;

        swapper.swap(swapStruct_);
    }

    function _createOrder(AnnouncementData calldata announcementData_, uint256 collateralAmount_) internal {
        IFlatcoinVault vault = getVault();

        if (announcementData_.orderType == DelayedOrderStructs.OrderType.StableDeposit) {
            DepositData memory depositAnnouncementData = abi.decode(announcementData_.data, (DepositData));

            // Ensure that the collateral received is greater than the keeper fee.
            if (collateralAmount_ <= depositAnnouncementData.keeperFee)
                revert NotEnoughCollateralAfterFees(collateralAmount_, depositAnnouncementData.keeperFee);

            // Note that as the keeper fee is deducted from the collateral, it becomes crucial to calculate the minAmountOut correctly
            // by accounting for the slippage incurred during the swap.
            // We are subtracting the keeper fee from the collateral received as the amount of collateral transferred to the
            // OrderExecution module is equivalent to the `depositAmount + keeperFee`.
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .announceStableDepositFor({
                    depositAmount: collateralAmount_ - depositAnnouncementData.keeperFee,
                    minAmountOut: depositAnnouncementData.minAmountOut,
                    keeperFee: depositAnnouncementData.keeperFee,
                    receiver: msg.sender
                });
        } else if (announcementData_.orderType == DelayedOrderStructs.OrderType.LeverageOpen) {
            LeverageOpenData memory leverageOpenData = abi.decode(announcementData_.data, (LeverageOpenData));

            uint256 fees = leverageOpenData.keeperFee +
                FeeManager(address(vault)).getTradeFee(leverageOpenData.additionalSize);

            // Ensure that the collateral received is greater than the fees to be paid.
            if (collateralAmount_ <= fees) revert NotEnoughCollateralAfterFees(collateralAmount_, fees);

            uint256 margin = collateralAmount_ - fees;

            // As the keeper fee and trade fee is deducted from the collateral, we need to ensure that the margin is sufficient.
            if (margin < leverageOpenData.minMargin)
                revert AmountReceivedForMarginTooSmall(collateralAmount_, leverageOpenData.minMargin);

            // We are subtracting the keeper fee from the collateral received as the amount of collateral transferred to the
            // OrderExecution module is equivalent to the `margin + keeperFee + tradeFee`.
            IOrderAnnouncementModule(vault.moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY))
                .announceLeverageOpenFor({
                    margin: margin,
                    additionalSize: leverageOpenData.additionalSize,
                    maxFillPrice: leverageOpenData.maxFillPrice,
                    stopLossPrice: leverageOpenData.stopLossPrice,
                    profitTakePrice: leverageOpenData.profitTakePrice,
                    keeperFee: leverageOpenData.keeperFee,
                    receiver: msg.sender
                });
        } else {
            revert InvalidOrderType();
        }
    }

    /// @dev Function to approve the spender to spend an unlimited amount of the token.
    /// @dev The function checks if the allowance is less than half of the `uint256` max value before max approving.
    ///      Because if it compared with uint256 max value, it will always be less than that.
    /// @param token_ The token to approve.
    /// @param spender_ The address to approve.
    function _unlimitedApprove(IERC20 token_, address spender_) private {
        uint256 currentAllowance = token_.allowance(address(this), spender_);
        if (currentAllowance < type(uint256).max / 2)
            token_.safeIncreaseAllowance(spender_, type(uint256).max - currentAllowance);
    }

    //////////////////////////
    //    Admin functions   //
    //////////////////////////

    /// @notice Sets the address of the FlatcoinVault to zap into.
    /// @param vault_ The address of the collateral token.
    function setVault(IFlatcoinVault vault_) external onlyOwner {
        if (address(vault_) == address(0)) revert ZeroAddress("vault");

        _setVault(vault_);
    }

    /// @notice Sets the address of the collateral token.
    /// @dev Useful in case the collateral token is updated.
    /// @param newCollateral_ The address of the collateral token.
    function setCollateral(IERC20 newCollateral_) external onlyOwner {
        if (address(newCollateral_) == address(0)) revert ZeroAddress("newCollateral");

        _setCollateral(newCollateral_);
        _unlimitedApprove(newCollateral_, getVault().moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY));
    }

    /// @notice Sets the address of the Swapper contract.
    /// @param newSwapper_ The address of the Swapper contract.
    function setSwapper(ISwapper newSwapper_) external onlyOwner {
        if (address(newSwapper_) == address(0)) revert ZeroAddress("newSwapper");

        _setSwapper(newSwapper_);
    }

    /// @notice Approve the order announcement module to spend an unlimited amount of the collateral token.
    /// @dev In case the OrderAnnouncement module is updated, this function can be called to approve the new module address.
    function unlimitedApproveOrderAnnouncementModule() external onlyOwner {
        address orderAnnouncementModule = getVault().moduleAddress(FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY);

        _unlimitedApprove(getCollateral(), orderAnnouncementModule);
    }

    /// @notice Rescue funds from the contract.
    /// @param token_ Address of the token to be rescued.
    /// @param to_ Address to which the funds will be transferred.
    /// @param amount_ Amount of tokens to be rescued.
    function rescueFunds(IERC20 token_, address to_, uint256 amount_) external onlyOwner {
        token_.safeTransfer(to_, amount_);
    }

    function setWrappedNativeToken(IWETH wrappedNativeToken_) external onlyOwner {
        _setWrappedNativeTokenAddress(wrappedNativeToken_);
    }
}
