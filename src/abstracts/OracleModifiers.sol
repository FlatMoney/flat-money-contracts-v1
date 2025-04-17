// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IFlatcoinVault} from "../interfaces/IFlatcoinVault.sol";
import {IOracleModule} from "../interfaces/IOracleModule.sol";
import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";

/// @title OracleModifiers
/// @author dHEDGE
/// @notice Contract containing necessary modifiers for Oracle related functions.
abstract contract OracleModifiers {
    /// @dev Important to use this modifier in functions which require the Pyth network price to be updated.
    ///      Otherwise, the invariant checks or any other logic which depends on the Pyth network price may not be correct.
    modifier updatePythPrice(
        IFlatcoinVault vault_,
        address sender_,
        bytes[] calldata priceUpdateData_
    ) {
        IOracleModule(vault_.moduleAddress(FlatcoinModuleKeys._ORACLE_MODULE_KEY)).updatePythPrice{value: msg.value}(
            sender_,
            priceUpdateData_
        );
        _;
    }
}
