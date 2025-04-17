// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

import {Setup} from "../../helpers/Setup.sol";

import {MockGasPriceOracleConfig} from "../../mocks/MockGasPriceOracleConfig.sol";

import "../../helpers/Setup.sol";
import {KeeperFeeBase} from "../../../src/abstracts/KeeperFeeBase.sol";

import "forge-std/console2.sol";

contract KeeperFeeTest is Setup {
    uint256 internal stalenessPeriod = 1200;
    OPKeeperFee internal keeperFeeContract;

    function setUp() public override {
        super.setUp();

        keeperFeeContract = new OPKeeperFee({
            owner_: admin,
            ethOracle_: address(collateralChainlinkAggregatorV3),
            oracleModule_: address(oracleModProxy),
            assetToPayWith_: address(collateralAsset),
            profitMarginPercent_: 0.3e18,
            keeperFeeUpperBound_: 30e18, // In USD
            keeperFeeLowerBound_: 2e18, // In USD
            gasUnitsL1_: 30_000,
            gasUnitsL2_: 1_200_000,
            stalenessPeriod_: stalenessPeriod
        });
    }

    function test_keeper_fee() public {
        vm.startPrank(admin);
        // This tests the actual KeeperFee.sol contract (doesn't use the MockKeeperFee).
        // It uses a MockGasPriceOracleConfig contract for gas price estimation settings.

        MockGasPriceOracleConfig mockGasPriceOracle = new MockGasPriceOracleConfig();

        uint256 wethPrice = 2000e8;

        setCollateralPrice(wethPrice);

        vaultProxy.addAuthorizedModule(
            FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY,
                moduleAddress: address(keeperFeeContract)
            })
        );

        keeperFeeContract.setGasPriceOracle(address(mockGasPriceOracle));

        uint256 keeperFee = keeperFeeContract.getKeeperFee();

        (
            address gasPriceOracle,
            uint256 profitMarginPercent,
            uint256 keeperFeeUpperBound,
            uint256 keeperFeeLowerBound,
            uint256 gasUnitsL1,
            uint256 gasUnitsL2,
            uint256 configStalenessPeriod
        ) = keeperFeeContract.getConfig();

        // Expected keeper fee using specific MockGasPriceOracleConfig settings.
        // NOTE: The fee is around $1.62 but as this is lesser than the lower bound of $2, the lower bound is used.
        //       Also this fee is returned in the collateral asset (collateralAsset) so the hardcoded value is in collateralAsset.
        assertEq(keeperFee, (2e18 * 1e8) / wethPrice, "Invalid keeper fee value");

        assertGe(keeperFee, (keeperFeeLowerBound * 1e8) / wethPrice, "Keeper fee hit lower bound");
        assertLe(keeperFee, (keeperFeeUpperBound * 1e8) / wethPrice, "Keeper fee hit upper bound");
        assertEq(gasPriceOracle, address(mockGasPriceOracle), "Invalid gasPriceOracle");
        assertEq(profitMarginPercent, 0.3e18, "Invalid profitMarginPercent");
        assertEq(keeperFeeUpperBound, 30e18, "Invalid keeperFeeUpperBound");
        assertEq(keeperFeeLowerBound, 2e18, "Invalid keeperFeeLowerBound");
        assertEq(gasUnitsL1, 30_000, "Invalid gasUnitsL1");
        assertEq(gasUnitsL2, 1_200_000, "Invalid gasUnitsL2");
        assertEq(configStalenessPeriod, stalenessPeriod, "Invalid stalenessPeriod");
    }

    function test_keeper_fee_revert_if_price_stale() public {
        skip(stalenessPeriod * 2);

        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1000e8, 0, block.timestamp - stalenessPeriod - 1, 0)
        );
        vm.mockCall(0x420000000000000000000000000000000000000F, abi.encodeWithSignature("baseFee()"), abi.encode(271)); // Base fee set as 271 wei.

        vm.expectRevert(abi.encodeWithSelector(KeeperFeeBase.ETHPriceStale.selector));
        keeperFeeContract.getKeeperFee();
    }

    function test_keeper_fee_revert_if_ETH_price_invalid() public {
        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, -1000e8, 0, block.timestamp, 0)
        );

        vm.mockCall(0x420000000000000000000000000000000000000F, abi.encodeWithSignature("baseFee()"), abi.encode(271)); // Base fee set as 271 wei.

        vm.expectRevert(abi.encodeWithSelector(KeeperFeeBase.ETHPriceInvalid.selector));
        keeperFeeContract.getKeeperFee();
    }

    function test_keeper_fee_revert_if_collateral_price_invalid() public {
        vm.mockCall(
            address(oracleModProxy),
            abi.encodeWithSignature("getPrice(address)", address(collateralAsset)),
            abi.encode(0, block.timestamp)
        );

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.PriceInvalid.selector, OracleModuleStructs.PriceSource.OnChain)
        );
        vm.mockCall(0x420000000000000000000000000000000000000F, abi.encodeWithSignature("baseFee()"), abi.encode(271)); // Base fee set as 271 wei.

        keeperFeeContract.getKeeperFee();
    }

    function test_keeper_fee_revert_if_collateral_price_stale() public {
        skip(1 weeks);

        vm.mockCall(
            address(collateralChainlinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, 1000e8, 0, block.timestamp, 0)
        );
        vm.mockCall(0x420000000000000000000000000000000000000F, abi.encodeWithSignature("baseFee()"), abi.encode(271)); // Base fee set as 271 wei.
        vm.mockCall(
            address(oracleModProxy),
            abi.encodeWithSignature("getPrice(address)", address(collateralAsset)),
            abi.encode(1000e8, 1)
        );

        vm.expectRevert(
            abi.encodeWithSelector(ICommonErrors.PriceStale.selector, OracleModuleStructs.PriceSource.OnChain)
        );
        keeperFeeContract.getKeeperFee();
    }
}
