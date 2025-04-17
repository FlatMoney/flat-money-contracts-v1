// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "./structs/DelayedOrderStructs.sol" as DelayedOrderStructs;
import "./structs/OracleModuleStructs.sol" as OracleModuleStructs;

interface ICommonErrors {
    ////////////////////////////////////////
    //               Errors               //
    ////////////////////////////////////////

    error MaxPositionsReached();

    error InvalidFee(uint256 fee);

    error PositionCreatesBadDebt();

    error ZeroValue(string variableName);

    error ZeroAddress(string variableName);

    error MaxSkewReached(uint256 skewFraction);

    error ValueNotPositive(string variableName);

    error OnlyAuthorizedModule(address msgSender);

    error InvalidPercentageValue(uint64 percentage);

    error HighSlippage(uint256 supplied, uint256 accepted);

    error ExecutableTimeNotReached(uint256 executableTime);

    error AmountTooSmall(uint256 amount, uint256 minAmount);

    error NotTokenOwner(uint256 tokenId, address msgSender);

    error OrderExists(DelayedOrderStructs.OrderType orderType);

    error PriceStale(OracleModuleStructs.PriceSource priceSource);

    error PriceInvalid(OracleModuleStructs.PriceSource priceSource);

    error NotEnoughMarginForFees(int256 marginAmount, uint256 feeAmount);
}
