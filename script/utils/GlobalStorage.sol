// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

/// @dev Contract to hold global storage variables.
///      This contract basically mocks a contract function to return a value that needs to be
///      shared among all script files.
abstract contract GlobalStorage is Script {
    address internal _globalStorage = makeAddr("globalStorage");

    /// @dev Function to set a particular key-value pair in the global storage.
    /// @param key The key to set in the global storage. Should be in the form of a function signature.
    ///        Example: "tag()".
    /// @param value The value to set in the global storage. Should be ABI encoded.
    function setStorage(string memory key, bytes memory value) internal {
        vm.mockCall(_globalStorage, abi.encodeWithSignature(key), value);
    }
}
