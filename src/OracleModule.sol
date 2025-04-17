// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

import {ICommonErrors} from "./interfaces/ICommonErrors.sol";
import {IOracleModule} from "./interfaces/IOracleModule.sol";
import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";

import "./interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

/// @title OracleModule
/// @author dHEDGE
/// @notice Can query collateral oracle price.
/// @dev Interfaces with onchain and offchain oracles (eg. Chainlink and Pyth network).
contract OracleModule is IOracleModule, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeCast for *;
    using SignedMath for int256;

    /////////////////////////////////////////////
    //                Events                   //
    /////////////////////////////////////////////

    event SetMaxDiffPercent(uint256 maxDiffPercent);
    event SetOnChainOracle(OracleModuleStructs.OnchainOracle oracle);
    event SetOffChainOracle(OracleModuleStructs.OffchainOracle oracle);

    /////////////////////////////////////////////
    //                Errors                   //
    /////////////////////////////////////////////

    error RefundFailed();
    error OracleConfigInvalid();
    error PriceMismatch(uint256 diffPercent);

    /////////////////////////////////////////////
    //                State                    //
    /////////////////////////////////////////////

    bytes32 public constant MODULE_KEY = FlatcoinModuleKeys._ORACLE_MODULE_KEY;

    IPyth public pythOracleContract;

    mapping(address asset => OracleModuleStructs.OracleData oracleData) private _oracles;

    /////////////////////////////////////////////
    //         Initialization Functions        //
    /////////////////////////////////////////////

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    /// @param owner_ The owner of the contract.
    /// @param pythContract_ The Pyth contract address.
    function initialize(address owner_, IPyth pythContract_) external initializer {
        __Ownable_init(owner_);
        __ReentrancyGuard_init();

        pythOracleContract = pythContract_;
    }

    /////////////////////////////////////////////
    //          Public Write Functions         //
    /////////////////////////////////////////////

    /// @param sender_ The sender address.
    /// @param priceUpdateData_ The Pyth network offchain price oracle update data.
    function updatePythPrice(address sender_, bytes[] calldata priceUpdateData_) external payable nonReentrant {
        // Get fee amount to pay to Pyth
        uint256 fee = pythOracleContract.getUpdateFee(priceUpdateData_);

        // Update the price data (and pay the fee)
        pythOracleContract.updatePriceFeeds{value: fee}(priceUpdateData_);

        if (msg.value - fee > 0) {
            // Need to refund caller. Try to return unused value, or revert if failed
            (bool success, ) = sender_.call{value: msg.value - fee}("");
            if (success == false) revert RefundFailed();
        }
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Returns the latest 18 decimal price of asset from either Pyth network or Chainlink.
    /// @dev The oldest pricestamp will be the Chainlink oracle `maxAge` setting. Otherwise the call will revert.
    /// @param asset_ The asset to get the price of (in USD terms).
    /// @return price_ The latest 18 decimal price of asset.
    /// @return timestamp_ The timestamp of the latest price.
    function getPrice(address asset_) public view returns (uint256 price_, uint256 timestamp_) {
        (price_, timestamp_) = _getPrice(asset_, type(uint32).max, false);
    }

    /// @notice The same as getPrice() but it includes maximum acceptable oracle timestamp input parameter.
    /// @param asset_ The asset to get the price of (in USD terms).
    /// @param maxAge_ Oldest acceptable oracle price.
    /// @param priceDiffCheck_ If true, it will check the price difference between onchain and offchain oracle.
    /// @return price_ The latest 18 decimal price of asset.
    /// @return timestamp_ The timestamp of the latest price.
    function getPrice(
        address asset_,
        uint32 maxAge_,
        bool priceDiffCheck_
    ) public view returns (uint256 price_, uint256 timestamp_) {
        (price_, timestamp_) = _getPrice(asset_, maxAge_, priceDiffCheck_);
    }

    /// @notice Returns the oracle data for a given asset.
    /// @param asset_ The ERC20 asset address.
    /// @return oracleData_ The oracle data for the asset.
    function getOracleData(address asset_) external view returns (OracleModuleStructs.OracleData memory oracleData_) {
        return _oracles[asset_];
    }

    /////////////////////////////////////////////
    //            Internal Functions           //
    /////////////////////////////////////////////

    /// @notice Returns the latest 18 decimal price of asset from either Pyth network or Chainlink.
    /// @dev It verifies the Pyth network price against Chainlink price (ensure that it is within a threshold).
    /// @param asset_ The asset to get the price of (in USD terms).
    /// @param maxAge_ Oldest acceptable oracle price.
    /// @param priceDiffCheck_ If true, it will check the price difference between onchain and offchain oracle.
    /// @return price_ The latest 18 decimal price of asset.
    /// @return timestamp_ The timestamp of the latest price.
    function _getPrice(
        address asset_,
        uint32 maxAge_,
        bool priceDiffCheck_
    ) internal view returns (uint256 price_, uint256 timestamp_) {
        (uint256 onchainPrice, uint256 onchainTime) = _getOnchainPrice(asset_); // will revert if invalid
        (uint256 offchainPrice, uint256 offchainTime, bool offchainInvalid) = _getOffchainPrice(asset_);
        bool offchain;

        if (offchainInvalid == false) {
            if (priceDiffCheck_) {
                // If the price is not time sensitive (not used for order execution),
                // then we don't need to check the price difference between onchain and offchain
                uint256 priceDiff = (int256(onchainPrice) - int256(offchainPrice)).abs();
                uint256 diffPercent = (priceDiff * 1e18) /
                    (onchainPrice < offchainPrice ? onchainPrice : offchainPrice);
                if (diffPercent > _oracles[asset_].maxDiffPercent) revert PriceMismatch(diffPercent);
            }

            // return the freshest price
            if (offchainTime >= onchainTime) {
                price_ = offchainPrice;
                timestamp_ = offchainTime;
                offchain = true;
            } else {
                price_ = onchainPrice;
                timestamp_ = onchainTime;
            }
        } else {
            price_ = onchainPrice;
            timestamp_ = onchainTime;
        }

        // Check that the timestamp is within the required age
        if (maxAge_ < type(uint32).max && timestamp_ + maxAge_ < block.timestamp) {
            revert ICommonErrors.PriceStale(
                offchain ? OracleModuleStructs.PriceSource.OffChain : OracleModuleStructs.PriceSource.OnChain
            );
        }
    }

    /// @notice Fetches the price of collateral from Chainlink oracle.
    /// @dev Will revert on any issue. This is because the Onchain price is critical
    ///      Mind the Chainlink oracle price decimals if switching to ETH pair (18 decimals)
    /// @return price_ The latest 18 decimal price of asset.
    /// @return timestamp_ The timestamp of the latest price.
    function _getOnchainPrice(address asset_) internal view returns (uint256 price_, uint256 timestamp_) {
        OracleModuleStructs.OracleData memory oracleData = _oracles[asset_];
        IChainlinkAggregatorV3 oracle = oracleData.onchainOracle.oracleContract;
        if (address(oracle) == address(0)) revert ICommonErrors.ZeroAddress("oracle");

        (, int256 price, , uint256 updatedAt, ) = oracle.latestRoundData();
        timestamp_ = updatedAt;
        // check Chainlink oracle price updated within `maxAge` time.
        if (block.timestamp > timestamp_ + oracleData.onchainOracle.maxAge)
            revert ICommonErrors.PriceStale(OracleModuleStructs.PriceSource.OnChain);

        if (price > 0) {
            // Convert the price from the oracle dictated decimals to 18 decimals.
            price_ = (uint256(price) * 1e18) / (10 ** (oracle.decimals()));
        } else {
            // Issue with onchain oracle indicates a serious problem
            revert ICommonErrors.PriceInvalid(OracleModuleStructs.PriceSource.OnChain);
        }
    }

    /// @notice Fetches the price of collateral from Pyth network price feed.
    /// @dev `_getPrice` can fall back to the Onchain oracle.
    /// @return price_ The latest 18 decimal price of asset.
    /// @return timestamp_ The timestamp of the latest price.
    /// @return invalid_ True if the price is invalid.
    function _getOffchainPrice(
        address asset_
    ) internal view returns (uint256 price_, uint256 timestamp_, bool invalid_) {
        OracleModuleStructs.OracleData memory oracleData = _oracles[asset_];
        if (address(pythOracleContract) == address(0)) revert ICommonErrors.ZeroAddress("oracle");

        try
            pythOracleContract.getPriceNoOlderThan(oracleData.offchainOracle.priceId, oracleData.offchainOracle.maxAge)
        returns (PythStructs.Price memory priceData) {
            timestamp_ = priceData.publishTime;

            // Check that Pyth price and confidence is a positive value
            // Check that the exponential param is negative (eg -8 for 8 decimals)
            if (priceData.price > 0 && priceData.conf > 0 && priceData.expo < 0) {
                price_ = ((priceData.price).toUint256()) * (10 ** (18 + priceData.expo).toUint256()); // convert oracle expo/decimals eg 8 -> 18

                // Check that Pyth price confidence meets minimum
                if (priceData.price / int64(priceData.conf) < int32(oracleData.offchainOracle.minConfidenceRatio)) {
                    invalid_ = true; // price confidence is too low
                }
            } else {
                invalid_ = true;
            }
        } catch {
            invalid_ = true; // couldn't fetch the price with the asked input param
        }
    }

    /// @notice Setting a Chainlink price feed push oracle.
    /// @param asset_ The asset to price.
    /// @param newOracle_ The Chainlink aggregator oracle address.
    function _setOnchainOracle(address asset_, OracleModuleStructs.OnchainOracle calldata newOracle_) internal {
        if (address(newOracle_.oracleContract) == address(0) || newOracle_.maxAge <= 0) revert OracleConfigInvalid();

        _oracles[asset_].onchainOracle = newOracle_;
        emit SetOnChainOracle(newOracle_);
    }

    /// @notice Setting a Pyth Network price feed pull oracle.
    /// @param asset_ The asset to price.
    /// @param newOracle_ The new onchain oracle configuration.
    function _setOffchainOracle(address asset_, OracleModuleStructs.OffchainOracle calldata newOracle_) internal {
        if (newOracle_.priceId == bytes32(0) || newOracle_.maxAge <= 0 || newOracle_.minConfidenceRatio <= 0)
            revert OracleConfigInvalid();

        _oracles[asset_].offchainOracle = OracleModuleStructs.OffchainOracle(
            newOracle_.priceId,
            newOracle_.maxAge,
            newOracle_.minConfidenceRatio
        );
        emit SetOffChainOracle(newOracle_);
    }

    /// @param asset_ The asset to price.
    /// @param maxDiffPercent_ The maximum percentage between onchain and offchain oracle.
    function _setMaxDiffPercent(address asset_, uint64 maxDiffPercent_) private {
        if (maxDiffPercent_ == 0 || maxDiffPercent_ > 1e18) revert OracleConfigInvalid();

        _oracles[asset_].maxDiffPercent = maxDiffPercent_;

        emit SetMaxDiffPercent(maxDiffPercent_);
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Sets the asset and _oracles (onchain and offchain).
    /// @dev Changes should be handled with care as it's possible to misconfigure.
    /// @param asset_ The asset to price.
    /// @param onchainOracle_ The onchain oracle configuration.
    /// @param offchainOracle_ The offchain oracle configuration.
    function setOracles(
        address asset_,
        OracleModuleStructs.OnchainOracle calldata onchainOracle_,
        OracleModuleStructs.OffchainOracle calldata offchainOracle_
    ) external onlyOwner {
        _setOnchainOracle(asset_, onchainOracle_);
        _setOffchainOracle(asset_, offchainOracle_);
    }

    /// @notice Setting the maximum percentage between onchain and offchain oracle.
    /// @dev Max diff percent must be between 0 and (or equal to) 100%.
    ///      0 means that we don't ever expect the oracle prices to differ.
    ///      1e18 means that we don't care if the oracle prices differ.
    /// @param asset_ The asset to price.
    /// @param maxDiffPercent_ The maximum percentage between onchain and offchain oracle.
    function setMaxDiffPercent(address asset_, uint64 maxDiffPercent_) external onlyOwner {
        _setMaxDiffPercent(asset_, maxDiffPercent_);
    }
}
