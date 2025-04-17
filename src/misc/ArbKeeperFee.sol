// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {KeeperFeeBase} from "../abstracts/KeeperFeeBase.sol";

// Interfaces
import {ICommonErrors} from "../interfaces/ICommonErrors.sol";
import {IArbGasInfo} from "../interfaces/IArbGasInfo.sol";
import "../interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

/// @title ArbKeeperFee
/// @notice A dynamic gas fee module to be used on Arb-stack L2s.
/// @dev Adapted from Synthetix ArbGasPriceOracle <https://github.com/Synthetixio/synthetix-v3/blob/8aff01938913983b97faa5ce082c15b86db32e0d/auxiliary/ArbitrumGasPriceOracle/contracts/ArbGasPriceOracle.sol#L8>.
contract ArbKeeperFee is KeeperFeeBase {
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
        _gasPriceOracle = 0x000000000000000000000000000000000000006C; // Arbitrum gas price oracle.
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @dev Returns computed gas price given on-chain variables.
    function getKeeperFee() public view override returns (uint256 keeperFeeCollateral_) {
        // fetch & define L2 gas price
        /// @dev perArbGasTotal is the best estimate of the L2 gas price "base fee" in wei
        (, , , , , uint256 perArbGasTotal) = IArbGasInfo(_gasPriceOracle).getPricesInWei();

        return getKeeperFee(perArbGasTotal);
    }

    /// @dev As adapted from Synthetix ArbGasPriceOracle <https://github.com/Synthetixio/synthetix-v3/blob/8aff01938913983b97faa5ce082c15b86db32e0d/auxiliary/ArbitrumGasPriceOracle/contracts/ArbGasPriceOracle.sol#L168>
    /// @dev Arbitrum docs for calculating gas fees for a transaction can be found here: <https://docs.arbitrum.io/build-decentralized-apps/how-to-estimate-gas#breaking-down-the-formula>
    /// @param baseFee_ The base fee in wei. This can be fetched from the gas price oracle by calling `getPricesInWei()`.
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

        // fetch & define L1 gas base fee; incorporate overhead buffer
        /// @dev if the estimate is too low or high at the time of the L1 batch submission,
        /// the transaction will still be processed, but the arbitrum nitro mechanism will
        /// amortize the deficit/surplus over subsequent users of the chain
        /// (i.e. lowering/raising the L1 base fee for a period of time)
        uint256 l1BaseFee = IArbGasInfo(_gasPriceOracle).getL1BaseFeeEstimate();

        // (1) calculate total fee:
        //   -> total_fee = P * G
        // where:
        // (2) P is the L2 basefee
        //   -> P = L2 basefee
        // (3) G is gas limit that also accounts for L1 dimension
        //   -> G = L2 gas used + ( L1 calldata price * L1 calldata size) / (L2 gas price)
        uint256 costOfExecutionGrossEth = baseFee_ * (_gasUnitsL2 + ((l1BaseFee * _gasUnitsL1) / baseFee_));
        uint256 costOfExecutionNet = costOfExecutionGrossEth.mulDiv(ethPrice18, _UNIT); // fee priced in USD

        keeperFeeCollateral_ = (_keeperFeeUpperBound.min(costOfExecutionNet.max(_keeperFeeLowerBound))).mulDiv(
            (10 ** IERC20Metadata(_assetToPayWith).decimals()),
            collateralPrice
        ); // fee priced in collateral
    }
}
