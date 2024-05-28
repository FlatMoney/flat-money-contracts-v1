// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {LeverageModule} from "../../src/LeverageModule.sol";

contract LeverageModuleHarness is LeverageModule {
    function exposed_lockCounter(uint256 tokenId) external view returns (uint8 lockCount) {
        return _lockCounter[tokenId].lockCount;
    }

    function exposed_lockedByModule(uint256 tokenId, bytes32 moduleKey) external view returns (bool locked) {
        return _lockCounter[tokenId].lockedByModule[moduleKey];
    }
}
