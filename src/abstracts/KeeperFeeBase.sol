// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FlatcoinModuleKeys} from "../libraries/FlatcoinModuleKeys.sol";

// Interfaces
import {ICommonErrors} from "../interfaces/ICommonErrors.sol";
import {IOracleModule} from "../interfaces/IOracleModule.sol";
import {IChainlinkAggregatorV3} from "../interfaces/IChainlinkAggregatorV3.sol";

/// @title KeeperFeeBase
/// @author dHEDGE
/// @notice Keeper fee computation base contract.
// solhint-disable no-empty-blocks
abstract contract KeeperFeeBase is Ownable {
    /////////////////////////////////////////////
    //                  Errors                 //
    /////////////////////////////////////////////

    error ETHPriceStale();
    error ETHPriceInvalid();

    /////////////////////////////////////////////
    //                 State                   //
    /////////////////////////////////////////////

    bytes32 public constant MODULE_KEY = FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY;

    address internal _gasPriceOracle; // Gas price oracles as deployed on L2s.
    IChainlinkAggregatorV3 internal _ethOracle; // ETH price for gas unit conversions
    IOracleModule internal _oracleModule; // for collateral asset pricing (the flatcoin market)

    uint256 internal constant _UNIT = 10 ** 18;
    uint256 internal _stalenessPeriod;

    address internal _assetToPayWith;
    uint256 internal _profitMarginPercent;
    uint256 internal _keeperFeeUpperBound;
    uint256 internal _keeperFeeLowerBound;
    uint256 internal _gasUnitsL1;
    uint256 internal _gasUnitsL2;

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
    ) Ownable(owner_) {
        // contracts
        _ethOracle = IChainlinkAggregatorV3(ethOracle_);
        _oracleModule = IOracleModule(oracleModule_);

        // params
        _assetToPayWith = assetToPayWith_;
        _profitMarginPercent = profitMarginPercent_;
        _keeperFeeUpperBound = keeperFeeUpperBound_; // In USD
        _keeperFeeLowerBound = keeperFeeLowerBound_; // In USD
        _gasUnitsL1 = gasUnitsL1_;
        _gasUnitsL2 = gasUnitsL2_;
        _stalenessPeriod = stalenessPeriod_;

        (, , , uint256 ethPriceupdatedAt, ) = _ethOracle.latestRoundData();

        // Check that the ETH oracle price is fresh.
        if (block.timestamp >= ethPriceupdatedAt + stalenessPeriod_) revert ETHPriceStale();
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @dev Returns computed gas price given on-chain variables.
    /// @return keeperFeeCollateral_ The computed keeper fee in collateral.
    function getKeeperFee() public view virtual returns (uint256 keeperFeeCollateral_) {}

    /// @return keeperFeeCollateral_ The computed keeper fee in collateral.
    function getKeeperFee(uint256 baseFee) public view virtual returns (uint256 keeperFeeCollateral_) {}

    /// @dev Returns the current configurations.
    /// @return gasPriceOracle_ The address of the gas price oracle.
    /// @return profitMarginPercent_ The profit margin percentage.
    /// @return keeperFeeUpperBound_ The upper bound of the keeper fee in USD.
    /// @return keeperFeeLowerBound_ The lower bound of the keeper fee in USD.
    /// @return gasUnitsL1_ The gas units for L1.
    /// @return gasUnitsL2_ The gas units for L2.
    /// @return stalenessPeriod_ The staleness period for the ETH oracle.
    function getConfig()
        external
        view
        virtual
        returns (
            address gasPriceOracle_,
            uint256 profitMarginPercent_,
            uint256 keeperFeeUpperBound_,
            uint256 keeperFeeLowerBound_,
            uint256 gasUnitsL1_,
            uint256 gasUnitsL2_,
            uint256 stalenessPeriod_
        )
    {
        gasPriceOracle_ = _gasPriceOracle;
        profitMarginPercent_ = _profitMarginPercent;
        keeperFeeUpperBound_ = _keeperFeeUpperBound;
        keeperFeeLowerBound_ = _keeperFeeLowerBound;
        gasUnitsL1_ = _gasUnitsL1;
        gasUnitsL2_ = _gasUnitsL2;
        stalenessPeriod_ = _stalenessPeriod;
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @dev Sets params used for gas price computation.
    function setParameters(
        uint256 profitMarginPercent_,
        uint256 keeperFeeUpperBound_,
        uint256 keeperFeeLowerBound_,
        uint256 gasUnitsL1_,
        uint256 gasUnitsL2_
    ) external virtual onlyOwner {
        _profitMarginPercent = profitMarginPercent_;
        _keeperFeeUpperBound = keeperFeeUpperBound_;
        _keeperFeeLowerBound = keeperFeeLowerBound_;
        _gasUnitsL1 = gasUnitsL1_;
        _gasUnitsL2 = gasUnitsL2_;
    }

    /// @dev Sets keeper fee upper and lower bounds.
    /// @param keeperFeeUpperBound_ The upper bound of the keeper fee in USD.
    /// @param keeperFeeLowerBound_ The lower bound of the keeper fee in USD.
    function setParameters(uint256 keeperFeeUpperBound_, uint256 keeperFeeLowerBound_) external virtual onlyOwner {
        if (keeperFeeUpperBound_ <= keeperFeeLowerBound_) revert ICommonErrors.InvalidFee(keeperFeeLowerBound_);
        if (keeperFeeLowerBound_ == 0) revert ICommonErrors.ZeroValue("keeperFeeLowerBound");

        _keeperFeeUpperBound = keeperFeeUpperBound_;
        _keeperFeeLowerBound = keeperFeeLowerBound_;
    }

    /// @dev Sets a custom gas price oracle. May be needed for some chain deployments.
    /// @param gasPriceOracle_ The address of the gas price oracle.
    function setGasPriceOracle(address gasPriceOracle_) external virtual onlyOwner {
        if (address(gasPriceOracle_) == address(0)) revert ICommonErrors.ZeroAddress("gasPriceOracle");

        _gasPriceOracle = gasPriceOracle_;
    }

    /// @dev Sets the staleness period for the ETH oracle.
    /// @param stalenessPeriod_ The staleness period for the ETH oracle.
    function setStalenessPeriod(uint256 stalenessPeriod_) external virtual onlyOwner {
        if (stalenessPeriod_ == 0) revert ICommonErrors.ZeroValue("stalenessPeriod");

        _stalenessPeriod = stalenessPeriod_;
    }
}
