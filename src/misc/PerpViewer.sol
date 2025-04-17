// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ViewerBase} from "../abstracts/ViewerBase.sol";
import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";

/// @title PerpViewer
/// @author dHEDGE
/// @notice A viewer contract for perp markets.
contract PerpViewer is ViewerBase {
    constructor(IFlatcoinVault vault_) ViewerBase(vault_) {}
}
