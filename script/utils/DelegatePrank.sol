// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import "forge-std/console.sol";

/* 
  Make arbitrary delegatecalls to an implementation contract.

  Supplements vm.prank.

  You already know how to make a contract c call dest.fn(args):

    vm.prank(c);
    dest.fn(args);

  Now, to make c delegatecall dest.fn(args):

    delegatePrank(c,address(dest),abi.encodeCall(fn,(args)));

*/
/// @dev Fetched the file from: https://github.com/ind-igo/forge-safe/blob/4ce820bad668846207f34b6f439021ad151f0a1e/src/lib/DelegatePrank.sol#L22-L23
contract DelegatePrank is CommonBase {
    Delegator delegator = makeDelegator();

    function makeDelegator() internal returns (Delegator) {
        return new Delegator();
    }

    function delegatePrank(address from, address to, bytes memory cd) public returns (bool success, bytes memory ret) {
        bytes memory code = from.code;
        vm.etch(from, address(delegator).code);
        (success, ret) = from.call(abi.encodeCall(delegator.etchCodeAndDelegateCall, (to, cd, code)));
    }
}

contract Delegator is CommonBase {
    function etchCodeAndDelegateCall(address dest, bytes memory cd, bytes calldata code) external payable virtual {
        vm.etch(address(this), code);
        assembly ("memory-safe") {
            let result := delegatecall(gas(), dest, add(cd, 32), mload(cd), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
