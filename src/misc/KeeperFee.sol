// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {FlatcoinErrors} from "../libraries/FlatcoinErrors.sol";
import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";

// Interfaces
import {IOracleModule} from "../interfaces/IOracleModule.sol";
import {IGasPriceOracle} from "../interfaces/IGasPriceOracle.sol";
import {IChainlinkAggregatorV3} from "../interfaces/IChainlinkAggregatorV3.sol";

/// @title KeeperFee
/// @notice A dynamic gas fee module to be used on L2s.
/// @dev Adapted from Synthetix PerpsV2DynamicFeesModule.
///      See https://sips.synthetix.io/sips/sip-2013
contract KeeperFee is Ownable {
    using Math for uint256;

    bytes32 public constant MODULE_KEY = FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY;

    IChainlinkAggregatorV3 private _ethOracle; // ETH price for gas unit conversions
    IGasPriceOracle private _gasPriceOracle = IGasPriceOracle(0x420000000000000000000000000000000000000F); // gas price oracle as deployed on Optimism L2 rollups
    IOracleModule private _oracleModule; // for collateral asset pricing (the flatcoin market)

    uint256 private constant _UNIT = 10 ** 18;
    uint256 private _stalenessPeriod;

    address private _assetToPayWith;
    uint256 private _profitMarginUSD;
    uint256 private _profitMarginPercent;
    uint256 private _keeperFeeUpperBound;
    uint256 private _keeperFeeLowerBound;
    uint256 private _gasUnitsL1;
    uint256 private _gasUnitsL2;

    constructor(
        address owner,
        address ethOracle,
        address oracleModule,
        address assetToPayWith,
        uint256 profitMarginUSD,
        uint256 profitMarginPercent,
        uint256 keeperFeeUpperBound,
        uint256 keeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2,
        uint256 stalenessPeriod
    ) Ownable(owner) {
        // contracts
        _ethOracle = IChainlinkAggregatorV3(ethOracle);
        _oracleModule = IOracleModule(oracleModule);

        // params
        _assetToPayWith = assetToPayWith;
        _profitMarginUSD = profitMarginUSD;
        _profitMarginPercent = profitMarginPercent;
        _keeperFeeUpperBound = keeperFeeUpperBound; // In USD
        _keeperFeeLowerBound = keeperFeeLowerBound; // In USD
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
        _stalenessPeriod = stalenessPeriod;

        // Check that the oracle asset price is valid
        (uint256 assetPrice, ) = IOracleModule(oracleModule).getPrice();

        if (assetPrice <= 0) revert FlatcoinErrors.PriceInvalid(FlatcoinErrors.PriceSource.OnChain);

        (, , , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

        // Check that the ETH oracle price is fresh.
        if (block.timestamp >= ethPriceupdatedAt + stalenessPeriod) revert FlatcoinErrors.ETHPriceStale();
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @dev Returns computed gas price given on-chain variables.
    function getKeeperFee() public view returns (uint256 keeperFeeCollateral) {
        return getKeeperFee(_gasPriceOracle.baseFee());
    }

    function getKeeperFee(uint256 baseFee) public view returns (uint256 keeperFeeCollateral) {
        uint256 ethPrice18;
        uint256 collateralPrice;
        {
            uint256 timestamp;

            (, int256 ethPrice, , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

            if (block.timestamp >= ethPriceupdatedAt + _stalenessPeriod) revert FlatcoinErrors.ETHPriceStale();
            if (ethPrice <= 0) revert FlatcoinErrors.ETHPriceInvalid();

            ethPrice18 = uint256(ethPrice) * 1e10; // from 8 decimals to 18
            // NOTE: Currently the market asset and collateral asset are the same.
            // If this changes in the future, then the following line should fetch the collateral asset, not market asset.
            (, uint32 maxAge) = _oracleModule.onchainOracle();
            (collateralPrice, timestamp) = _oracleModule.getPrice();

            if (collateralPrice <= 0) revert FlatcoinErrors.PriceInvalid(FlatcoinErrors.PriceSource.OnChain);

            if (block.timestamp >= timestamp + maxAge)
                revert FlatcoinErrors.PriceStale(FlatcoinErrors.PriceSource.OnChain);
        }

        bool isEcotone;
        try _gasPriceOracle.isEcotone() returns (bool _isEcotone) {
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
            uint256 gasPriceL2 = baseFee;
            uint256 baseFeeScalar = _gasPriceOracle.baseFeeScalar();
            uint256 l1BaseFee = _gasPriceOracle.l1BaseFee();
            uint256 blobBaseFeeScalar = _gasPriceOracle.blobBaseFeeScalar();
            uint256 blobBaseFee = _gasPriceOracle.blobBaseFee();
            uint256 decimals = _gasPriceOracle.decimals();

            uint256 l1GasPrice = (baseFeeScalar * l1BaseFee * 16 + blobBaseFeeScalar * blobBaseFee) /
                (16 * 10 ** decimals);

            costOfExecutionGrossEth = ((_gasUnitsL1 * l1GasPrice) + (_gasUnitsL2 * gasPriceL2));
        } else {
            // If it's not an ecotone, use the legacy formula and interface.
            uint256 gasPriceL2 = baseFee; // baseFee and gasPrice are the same in the legacy contract. Both return block.basefee.
            uint256 overhead = _gasPriceOracle.overhead();
            uint256 l1BaseFee = _gasPriceOracle.l1BaseFee();
            uint256 decimals = _gasPriceOracle.decimals();
            uint256 scalar = _gasPriceOracle.scalar();

            costOfExecutionGrossEth = ((((_gasUnitsL1 + overhead) * l1BaseFee * scalar) / 10 ** decimals) +
                (_gasUnitsL2 * gasPriceL2));
        }

        uint256 costOfExecutionGrossUSD = costOfExecutionGrossEth.mulDiv(ethPrice18, _UNIT); // fee priced in USD

        uint256 maxProfitMargin = _profitMarginUSD.max(costOfExecutionGrossUSD.mulDiv(_profitMarginPercent, _UNIT)); // additional USD profit for the keeper
        uint256 costOfExecutionNet = costOfExecutionGrossUSD + maxProfitMargin; // fee priced in USD

        keeperFeeCollateral = (_keeperFeeUpperBound.min(costOfExecutionNet.max(_keeperFeeLowerBound))).mulDiv(
            _UNIT,
            collateralPrice
        ); // fee priced in collateral
    }

    /// @dev Returns the current configurations.
    function getConfig()
        external
        view
        returns (
            address gasPriceOracle,
            uint256 profitMarginUSD,
            uint256 profitMarginPercent,
            uint256 keeperFeeUpperBound,
            uint256 keeperFeeLowerBound,
            uint256 gasUnitsL1,
            uint256 gasUnitsL2,
            uint256 stalenessPeriod
        )
    {
        gasPriceOracle = address(_gasPriceOracle);
        profitMarginUSD = _profitMarginUSD;
        profitMarginPercent = _profitMarginPercent;
        keeperFeeUpperBound = _keeperFeeUpperBound;
        keeperFeeLowerBound = _keeperFeeLowerBound;
        gasUnitsL1 = _gasUnitsL1;
        gasUnitsL2 = _gasUnitsL2;
        stalenessPeriod = _stalenessPeriod;
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @dev Sets params used for gas price computation.
    function setParameters(
        uint256 profitMarginUSD,
        uint256 profitMarginPercent,
        uint256 keeperFeeUpperBound,
        uint256 keeperFeeLowerBound,
        uint256 gasUnitsL1,
        uint256 gasUnitsL2
    ) external onlyOwner {
        _profitMarginUSD = profitMarginUSD;
        _profitMarginPercent = profitMarginPercent;
        _keeperFeeUpperBound = keeperFeeUpperBound;
        _keeperFeeLowerBound = keeperFeeLowerBound;
        _gasUnitsL1 = gasUnitsL1;
        _gasUnitsL2 = gasUnitsL2;
    }

    /// @dev Sets keeper fee upper and lower bounds.
    /// @param keeperFeeUpperBound The upper bound of the keeper fee in USD.
    /// @param keeperFeeLowerBound The lower bound of the keeper fee in USD.
    function setParameters(uint256 keeperFeeUpperBound, uint256 keeperFeeLowerBound) external onlyOwner {
        if (keeperFeeUpperBound <= keeperFeeLowerBound) revert FlatcoinErrors.InvalidFee(keeperFeeLowerBound);
        if (keeperFeeLowerBound == 0) revert FlatcoinErrors.ZeroValue("keeperFeeLowerBound");

        _keeperFeeUpperBound = keeperFeeUpperBound;
        _keeperFeeLowerBound = keeperFeeLowerBound;
    }

    /// @dev Sets a custom gas price oracle. May be needed for some chain deployments.
    function setGasPriceOracle(address gasPriceOracle) external onlyOwner {
        if (address(gasPriceOracle) == address(0)) revert FlatcoinErrors.ZeroAddress("gasPriceOracle");

        _gasPriceOracle = IGasPriceOracle(gasPriceOracle);
    }

    /// @dev Sets the staleness period for the ETH oracle.
    function setStalenessPeriod(uint256 stalenessPeriod) external onlyOwner {
        if (stalenessPeriod == 0) revert FlatcoinErrors.ZeroValue("stalenessPeriod");

        _stalenessPeriod = stalenessPeriod;
    }
}
