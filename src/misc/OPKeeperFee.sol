// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {KeeperFeeBase} from "../abstracts/KeeperFeeBase.sol";

// Interfaces
import {ICommonErrors} from "../interfaces/ICommonErrors.sol";
import {IGasPriceOracle} from "../interfaces/IGasPriceOracle.sol";
import "../interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

/// @title OPKeeperFee
/// @notice A dynamic gas fee module to be used on OP-stack L2s.
/// @dev Adapted from Synthetix PerpsV2DynamicFeesModule.
///      See https://sips.synthetix.io/sips/sip-2013
contract OPKeeperFee is KeeperFeeBase {
    using Math for uint256;

    constructor(
        address owner_,
        address ethOracle_,
        address oracleModule_,
        address assetToPayWith_,
        uint256 profitMarginPercent_,
        uint256 keeperFeeUpperBound_,
        uint256 keeperFeeLowerBound_,
        uint256 gasUnitsL1_,
        uint256 gasUnitsL2_,
        uint256 stalenessPeriod_
    )
        KeeperFeeBase(
            owner_,
            ethOracle_,
            oracleModule_,
            assetToPayWith_,
            profitMarginPercent_,
            keeperFeeUpperBound_,
            keeperFeeLowerBound_,
            gasUnitsL1_,
            gasUnitsL2_,
            stalenessPeriod_
        )
    {
        _gasPriceOracle = 0x420000000000000000000000000000000000000F;
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @dev Returns computed gas price given on-chain variables.
    function getKeeperFee() public view override returns (uint256 keeperFeeCollateral_) {
        return getKeeperFee(IGasPriceOracle(_gasPriceOracle).baseFee());
    }

    function getKeeperFee(uint256 baseFee_) public view override returns (uint256 keeperFeeCollateral_) {
        uint256 ethPrice18;
        uint256 collateralPrice;
        {
            uint256 timestamp;

            (, int256 ethPrice, , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

            if (block.timestamp >= ethPriceupdatedAt + _stalenessPeriod) revert ETHPriceStale();
            if (ethPrice <= 0) revert ETHPriceInvalid();

            ethPrice18 = uint256(ethPrice) * 1e10; // from 8 decimals to 18
            // NOTE: Currently the market asset and collateral asset are the same.
            // If this changes in the future, then the following line should fetch the collateral asset, not market asset.
            uint32 maxAge = _oracleModule.getOracleData(_assetToPayWith).onchainOracle.maxAge;
            (collateralPrice, timestamp) = _oracleModule.getPrice(_assetToPayWith);

            if (collateralPrice <= 0) revert ICommonErrors.PriceInvalid(OracleModuleStructs.PriceSource.OnChain);

            if (block.timestamp >= timestamp + maxAge)
                revert ICommonErrors.PriceStale(OracleModuleStructs.PriceSource.OnChain);
        }

        bool isEcotone;
        try IGasPriceOracle(_gasPriceOracle).isEcotone() returns (bool _isEcotone) {
            isEcotone = _isEcotone;
        } catch {
            // If the call fails, we assume it's not an ecotone. Explicitly setting it to false to avoid missunderstandings.
            isEcotone = false;
        }

        uint256 costOfExecutionGrossEth;

        // Note: The OVM GasPriceOracle scales the L1 gas fee by the decimals
        // Reference function `_getL1FeeBedrock` https://github.com/ethereum-optimism/optimism/blob/af9aa3369de8c3cbef0e491024fb83590492366c/packages/contracts-bedrock/src/L2/GasPriceOracle.sol#L128
        // The Synthetix implementation can be found in function `getCostofExecutionEth` https://github.com/Synthetixio/synthetix-v3/blob/e7932e96d8153db0716f1e5dd6df78c1a1ec711e/auxiliary/OpGasPriceOracle/contracts/OpGasPriceOracle.sol#L72
        if (isEcotone) {
            // If it's an ecotone, use the new formula and interface
            uint256 gasPriceL2 = baseFee_;
            uint256 baseFeeScalar = IGasPriceOracle(_gasPriceOracle).baseFeeScalar();
            uint256 l1BaseFee = IGasPriceOracle(_gasPriceOracle).l1BaseFee();
            uint256 blobBaseFeeScalar = IGasPriceOracle(_gasPriceOracle).blobBaseFeeScalar();
            uint256 blobBaseFee = IGasPriceOracle(_gasPriceOracle).blobBaseFee();
            uint256 decimals = IGasPriceOracle(_gasPriceOracle).decimals();

            uint256 l1GasPrice = (baseFeeScalar * l1BaseFee * 16 + blobBaseFeeScalar * blobBaseFee) /
                (16 * 10 ** decimals);

            costOfExecutionGrossEth = ((_gasUnitsL1 * l1GasPrice) + (_gasUnitsL2 * gasPriceL2));
        } else {
            // If it's not an ecotone, use the legacy formula and interface.
            uint256 gasPriceL2 = baseFee_; // baseFee and gasPrice are the same in the legacy contract. Both return block.basefee.
            uint256 overhead = IGasPriceOracle(_gasPriceOracle).overhead();
            uint256 l1BaseFee = IGasPriceOracle(_gasPriceOracle).l1BaseFee();
            uint256 decimals = IGasPriceOracle(_gasPriceOracle).decimals();
            uint256 scalar = IGasPriceOracle(_gasPriceOracle).scalar();

            costOfExecutionGrossEth = ((((_gasUnitsL1 + overhead) * l1BaseFee * scalar) / 10 ** decimals) +
                (_gasUnitsL2 * gasPriceL2));
        }

        uint256 costOfExecutionNet = costOfExecutionGrossEth.mulDiv(ethPrice18, _UNIT); // fee priced in USD

        keeperFeeCollateral_ = (_keeperFeeUpperBound.min(costOfExecutionNet.max(_keeperFeeLowerBound))).mulDiv(
            (10 ** IERC20Metadata(_assetToPayWith).decimals()),
            collateralPrice
        ); // fee priced in collateral
    }
}
