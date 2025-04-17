// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ControllerBase} from "./abstracts/ControllerBase.sol";

import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";

/// @title PerpControllerModule
/// @author dHEDGE
/// @notice Controller module for the perp markets.
contract PerpControllerModule is ControllerBase {
    uint8 public constant CONTROLLER_TYPE = 1;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    function initialize(
        IFlatcoinVault vault_,
        uint256 maxFundingVelocity_,
        uint256 maxVelocitySkew_,
        uint256 targetSizeCollateralRatio_,
        int256 minFundingRate_
    ) external {
        __ControllerBase_init(
            vault_,
            maxFundingVelocity_,
            maxVelocitySkew_,
            targetSizeCollateralRatio_,
            minFundingRate_
        );
    }
}
