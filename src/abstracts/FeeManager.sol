// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {ICommonErrors} from "../interfaces/ICommonErrors.sol";

/// @title FeeManager
/// @author dHEDGE
/// @notice Fees management contract for the protocol.
abstract contract FeeManager is OwnableUpgradeable {
    ///////////////////////////////
    //           State           //
    ///////////////////////////////

    /// @notice Protocol fee collection address.
    address public protocolFeeRecipient;

    /// @notice The protocol fee percentage.
    /// @dev 1e18 = 100%
    uint64 public protocolFeePercentage;

    /// @notice Fee for stable LP redemptions.
    /// @dev 1e18 = 100%
    uint64 public stableWithdrawFee;

    /// @notice Charged for opening, adjusting or closing a position.
    /// @dev 1e18 = 100%
    uint64 public leverageTradingFee;

    ///////////////////////////////
    //    Initializer Function   //
    ///////////////////////////////

    // solhint-disable-next-line func-name-mixedcase
    function __FeeManager_init(
        address protocolFeeRecipient_,
        uint64 protocolFeePercentage_,
        uint64 stableWithdrawFee_,
        uint64 leverageTradingFee_
    ) internal {
        protocolFeeRecipient = protocolFeeRecipient_;
        protocolFeePercentage = protocolFeePercentage_;
        stableWithdrawFee = stableWithdrawFee_;
        leverageTradingFee = leverageTradingFee_;
    }

    ///////////////////////////////
    //      View Functions       //
    ///////////////////////////////

    /// @notice Returns the trade fee for a given size.
    /// @param size_ The size of the trade.
    /// @return tradeFee_ The trade fee.
    function getTradeFee(uint256 size_) external view returns (uint256 tradeFee_) {
        return (leverageTradingFee * size_) / 1e18;
    }

    function getWithdrawalFee(uint256 amount_) external view returns (uint256 withdrawalFee_) {
        return (stableWithdrawFee * amount_) / 1e18;
    }

    /// @notice Returns the protocol fee portion for a given trade fee amount.
    /// @param feeAmount_ The trade fee amount.
    /// @return protocolFeePortion_ The protocol fee portion.
    function getProtocolFee(uint256 feeAmount_) external view returns (uint256 protocolFeePortion_) {
        return (feeAmount_ * protocolFeePercentage) / 1e18;
    }

    ///////////////////////////////
    //     Private Functions     //
    ///////////////////////////////

    function _setProtocolFeeRecipient(address protocolFeeRecipient_) private {
        if (protocolFeeRecipient_ == address(0)) revert ICommonErrors.ZeroAddress("protocolFeeRecipient");

        protocolFeeRecipient = protocolFeeRecipient_;
    }

    function _setProtocolFeePercentage(uint64 protocolFeePercentage_) private {
        if (protocolFeePercentage_ > 1e18) revert ICommonErrors.InvalidPercentageValue(protocolFeePercentage_);

        protocolFeePercentage = protocolFeePercentage_;
    }

    function _setStableWithdrawFee(uint64 stableWithdrawFee_) private {
        if (stableWithdrawFee_ > 1e18) revert ICommonErrors.InvalidPercentageValue(stableWithdrawFee_);

        stableWithdrawFee = stableWithdrawFee_;
    }

    function _setLeverageTradingFee(uint64 leverageTradingFee_) private {
        if (leverageTradingFee_ > 1e18) revert ICommonErrors.InvalidPercentageValue(leverageTradingFee_);

        leverageTradingFee = leverageTradingFee_;
    }

    ///////////////////////////////
    //      Owner Functions      //
    ///////////////////////////////

    /// @notice Setter for the protocol fee recipient address.
    /// @param protocolFeeRecipient_ The address of the protocol fee recipient.
    function setProtocolFeeRecipient(address protocolFeeRecipient_) external onlyOwner {
        _setProtocolFeeRecipient(protocolFeeRecipient_);
    }

    /// @notice Setter for the protocol fee percentage.
    /// @param protocolFeePercentage_ The new protocol fee percentage.
    function setProtocolFeePercentage(uint64 protocolFeePercentage_) external onlyOwner {
        _setProtocolFeePercentage(protocolFeePercentage_);
    }

    /// @notice Setter for the leverage open/close fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param leverageTradingFee_ The new leverage trading fee.
    function setLeverageTradingFee(uint64 leverageTradingFee_) external onlyOwner {
        _setLeverageTradingFee(leverageTradingFee_);
    }

    /// @notice Setter for the stable withdraw fee.
    /// @dev Fees can be set to 0 if needed.
    /// @param stableWithdrawFee_ The new stable withdraw fee.
    function setStableWithdrawFee(uint64 stableWithdrawFee_) external onlyOwner {
        _setStableWithdrawFee(stableWithdrawFee_);
    }

    uint256[46] private __gap;
}
