// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ViewerBase} from "../abstracts/ViewerBase.sol";

import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";

/// @title OptionViewer
/// @author dHEDGE
/// @notice A viewer contract for options markets.
// solhint-disable no-empty-blocks
contract OptionViewer is ViewerBase {
    constructor(IFlatcoinVault vault_) ViewerBase(vault_) {}

    /// @dev Liquidation prices for options are not required as liquidations are only possible due to funding fee payments.
    function liquidationPrice(uint256 tokenId_) public view override returns (uint256 liqPrice_) {}

    /// @dev Liquidation prices for options are not required as liquidations are only possible due to funding fee payments.
    function liquidationPrice(
        uint256 tokenId_,
        uint256 marketPrice_
    ) public view override returns (uint256 liqPrice_) {}
}
