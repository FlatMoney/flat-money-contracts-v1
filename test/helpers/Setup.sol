// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {MockPyth} from "pyth-sdk-solidity/MockPyth.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";

import {ModuleUpgradeable} from "src/abstracts/ModuleUpgradeable.sol";
import {InvariantChecks} from "src/abstracts/InvariantChecks.sol";
import {FlatcoinVault} from "src/FlatcoinVault.sol";
import {OrderAnnouncementModule} from "src/OrderAnnouncementModule.sol";
import {OrderExecutionModule} from "src/OrderExecutionModule.sol";
import {PerpControllerModule} from "src/PerpControllerModule.sol";
import {OptionsControllerModule} from "src/OptionsControllerModule.sol";
import {StableModule} from "src/StableModule.sol";
import {OracleModule} from "src/OracleModule.sol";
import {LeverageModule} from "src/LeverageModule.sol";
import {LiquidationModule} from "src/LiquidationModule.sol";
import {PositionSplitterModule} from "src/PositionSplitterModule.sol";
import {PerpViewer} from "src/misc/PerpViewer.sol";
import {OptionViewer} from "src/misc/OptionViewer.sol";

import {OPKeeperFee} from "src/misc/OPKeeperFee.sol";
import {MockKeeperFee} from "../mocks/MockKeeperFee.sol";
import {FeeManager} from "src/abstracts/FeeManager.sol";
import {ControllerBase} from "src/abstracts/ControllerBase.sol";
import {ViewerBase} from "src/abstracts/ViewerBase.sol";

import "src/interfaces/structs/DelayedOrderStructs.sol" as DelayedOrderStructs;
import "src/interfaces/structs/FlatcoinVaultStructs.sol" as FlatcoinVaultStructs;
import "src/interfaces/structs/LeverageModuleStructs.sol" as LeverageModuleStructs;
import "src/interfaces/structs/OracleModuleStructs.sol" as OracleModuleStructs;

import "src/interfaces/structs/ViewerStructs.sol" as ViewerStructs;

import {FlatcoinModuleKeys} from "src/libraries/FlatcoinModuleKeys.sol";

import {IChainlinkAggregatorV3} from "src/interfaces/IChainlinkAggregatorV3.sol";
import {ICommonErrors} from "src/interfaces/ICommonErrors.sol";
import {ILeverageModule} from "src/interfaces/ILeverageModule.sol";
import {IFlatcoinVault} from "src/interfaces/IFlatcoinVault.sol";
import {IStableModule} from "src/interfaces/IStableModule.sol";
import {IKeeperFee} from "src/interfaces/IKeeperFee.sol";
import {IOrderAnnouncementModule} from "src/interfaces/IOrderAnnouncementModule.sol";
import {IOrderExecutionModule} from "src/interfaces/IOrderExecutionModule.sol";
import {IOracleModule} from "../../src/interfaces/IOracleModule.sol";
import {IGasPriceOracle} from "src/interfaces/IGasPriceOracle.sol";

import {MockERC20} from "../mocks/MockERC20.sol";

import "forge-std/Test.sol";
import "forge-std/console2.sol";

abstract contract Setup is Test {
    using stdStorage for StdStorage;

    enum ControllerType {
        PERP,
        OPTIONS
    }

    struct PythPrice {
        uint256 price;
        bytes32 priceId;
    }

    /********************************************
     *                 Accounts                 *
     ********************************************/
    address internal admin = makeAddr("admin");

    address internal alice;
    uint256 internal alicePrivateKey;

    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal keeper = makeAddr("keeper");
    address internal liquidator = makeAddr("liquidator");
    address internal treasury = makeAddr("treasury");
    address internal feeRecipient = makeAddr("feeRecipient");
    address[] internal accounts = [admin, bob, carol, keeper, liquidator, treasury, feeRecipient];

    /********************************************
     *                 Mocks                    *
     ********************************************/
    IChainlinkAggregatorV3 internal collateralChainlinkAggregatorV3 =
        IChainlinkAggregatorV3(makeAddr("collateralChainlinkAggregatorV3"));

    // Tokens
    MockERC20 internal collateralAsset;

    MockPyth internal mockPyth; // validTimePeriod, singleUpdateFeeInWei
    IKeeperFee internal mockKeeperFee;
    bytes32 internal collateralPythId = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;

    /********************************************
     *             System contracts             *
     ********************************************/
    bytes32 internal constant STABLE_MODULE_KEY = FlatcoinModuleKeys._STABLE_MODULE_KEY;
    bytes32 internal constant LEVERAGE_MODULE_KEY = FlatcoinModuleKeys._LEVERAGE_MODULE_KEY;
    bytes32 internal constant ORACLE_MODULE_KEY = FlatcoinModuleKeys._ORACLE_MODULE_KEY;
    bytes32 internal constant ORDER_ANNOUNCEMENT_MODULE_KEY = FlatcoinModuleKeys._ORDER_ANNOUNCEMENT_MODULE_KEY;
    bytes32 internal constant ORDER_EXECUTION_MODULE_KEY = FlatcoinModuleKeys._ORDER_EXECUTION_MODULE_KEY;
    bytes32 internal constant LIQUIDATION_MODULE_KEY = FlatcoinModuleKeys._LIQUIDATION_MODULE_KEY;
    bytes32 internal constant KEEPER_FEE_MODULE_KEY = FlatcoinModuleKeys._KEEPER_FEE_MODULE_KEY;
    bytes32 internal constant CONTROLLER_MODULE_KEY = FlatcoinModuleKeys._CONTROLLER_MODULE_KEY;
    bytes32 internal constant POSITION_SPLITTER_MODULE_KEY = FlatcoinModuleKeys._POSITION_SPLITTER_MODULE_KEY;

    address internal leverageModImplementation;
    address internal stableModImplementation;
    address internal oracleModImplementation;
    address internal orderAnnouncementModImplementation;
    address internal orderExecutionModImplementation;
    address internal limitOrderImplementation;
    address internal liquidationModImplementation;
    address internal vaultImplementation;
    address internal perpControllerModImplementation;
    address internal optionsControllerModImplementation;
    address internal positionSplitterImplementation;

    ProxyAdmin internal proxyAdmin;
    LeverageModule internal leverageModProxy;
    StableModule internal stableModProxy;
    OracleModule internal oracleModProxy;
    OrderAnnouncementModule internal orderAnnouncementModProxy;
    OrderExecutionModule internal orderExecutionModProxy;
    LiquidationModule internal liquidationModProxy;
    FlatcoinVault internal vaultProxy;
    ControllerBase internal controllerModProxy;
    PerpControllerModule internal perpControllerModProxy;
    OptionsControllerModule internal optionsControllerModProxy;
    ViewerBase internal viewer;
    PositionSplitterModule internal positionSplitterProxy;

    /********************************************
     *             Current State                *
     ********************************************/

    /// @dev Note that the prices are with 18 decimals.
    uint256 collateralAssetPrice;

    function setUp() public virtual {
        setUpDefaultWithController(ControllerType.PERP);
    }

    function setUpDefaultWithController(ControllerType controller_) public virtual {
        {
            collateralAsset = new MockERC20();
            collateralAsset.initialize("collateral", "collateralAsset", 18);
        }

        vm.label(address(collateralAsset), "collateralAsset");

        setUpWithController({collateral_: collateralAsset, controller_: controller_});
    }

    function setUpWithController(MockERC20 collateral_, ControllerType controller_) public virtual {
        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        accounts.push(alice);

        vm.startPrank(admin);

        mockPyth = new MockPyth(60, 1);

        // Deploy proxy admin for all the system contracts.
        proxyAdmin = new ProxyAdmin(admin);

        // Deploy implementations of all the system contracts.
        leverageModImplementation = address(new LeverageModule());
        stableModImplementation = address(new StableModule());
        oracleModImplementation = address(new OracleModule());
        orderAnnouncementModImplementation = address(new OrderAnnouncementModule());
        orderExecutionModImplementation = address(new OrderExecutionModule());
        liquidationModImplementation = address(new LiquidationModule());
        vaultImplementation = address(new FlatcoinVault());
        perpControllerModImplementation = address(new PerpControllerModule());
        optionsControllerModImplementation = address(new OptionsControllerModule());
        positionSplitterImplementation = address(new PositionSplitterModule());

        // Deploy proxies using the above implementation contracts.
        leverageModProxy = LeverageModule(
            address(new TransparentUpgradeableProxy(leverageModImplementation, address(proxyAdmin), ""))
        );
        stableModProxy = StableModule(
            address(new TransparentUpgradeableProxy(stableModImplementation, address(proxyAdmin), ""))
        );
        oracleModProxy = OracleModule(
            address(new TransparentUpgradeableProxy(oracleModImplementation, address(proxyAdmin), ""))
        );
        orderAnnouncementModProxy = OrderAnnouncementModule(
            address(new TransparentUpgradeableProxy(orderAnnouncementModImplementation, address(proxyAdmin), ""))
        );
        orderExecutionModProxy = OrderExecutionModule(
            address(new TransparentUpgradeableProxy(orderExecutionModImplementation, address(proxyAdmin), ""))
        );
        liquidationModProxy = LiquidationModule(
            address(new TransparentUpgradeableProxy(liquidationModImplementation, address(proxyAdmin), ""))
        );
        vaultProxy = FlatcoinVault(
            address(new TransparentUpgradeableProxy(vaultImplementation, address(proxyAdmin), ""))
        );
        perpControllerModProxy = PerpControllerModule(
            address(new TransparentUpgradeableProxy(perpControllerModImplementation, address(proxyAdmin), ""))
        );
        optionsControllerModProxy = OptionsControllerModule(
            address(new TransparentUpgradeableProxy(optionsControllerModImplementation, address(proxyAdmin), ""))
        );
        positionSplitterProxy = PositionSplitterModule(
            address(new TransparentUpgradeableProxy(positionSplitterImplementation, address(proxyAdmin), ""))
        );

        // Labelling the system contracts.
        {
            vm.label(address(vaultProxy), "FlatcoinVaultProxy");
            vm.label(address(leverageModProxy), "LeverageModuleProxy");
            vm.label(address(stableModProxy), "StableModuleProxy");
            vm.label(address(oracleModProxy), "OracleModuleProxy");
            vm.label(address(orderAnnouncementModProxy), "OrderAnnouncementModuleProxy");
            vm.label(address(orderExecutionModProxy), "OrderExecutionModuleProxy");
            vm.label(address(liquidationModProxy), "LiquidationModuleProxy");
            vm.label(address(perpControllerModProxy), "PerpControllerModuleProxy");
            vm.label(address(optionsControllerModProxy), "OptionsControllerModuleProxy");
            vm.label(address(positionSplitterProxy), "PositionSplitterModuleProxy");
        }

        // Initialize the vault.
        // By default, max funding velocity will be 0.
        vaultProxy.initialize({
            collateral_: IERC20Metadata(address(collateral_)),
            protocolFeeRecipient_: feeRecipient,
            protocolFeePercentage_: 20e16, // 20% protocol fee. Will only be charged when leverage and stable withdrawal fees are charged.
            leverageTradingFee_: 0,
            stableWithdrawFee_: 0,
            maxDeltaError_: 1e6, // Absolute error margin of 1e6.
            skewFractionMax_: 1.2e18,
            stableCollateralCap_: type(uint256).max,
            maxPositions_: 0
        });

        /* Initialize the modules */

        if (controller_ == ControllerType.PERP) {
            perpControllerModProxy.initialize({
                vault_: vaultProxy,
                maxFundingVelocity_: 0,
                maxVelocitySkew_: 0.1e18, // 10% skew to reach max funding velocity
                targetSizeCollateralRatio_: 1e18, // Delta neutral market
                minFundingRate_: type(int256).min // disable minimum funding rate
            });

            controllerModProxy = perpControllerModProxy;
            viewer = new PerpViewer(vaultProxy);
        } else {
            optionsControllerModProxy.initialize({
                vault_: vaultProxy,
                maxFundingVelocity_: 0,
                maxVelocitySkew_: 0.1e18, // 10% skew to reach max funding velocity
                targetSizeCollateralRatio_: 1e18, // Delta neutral market
                minFundingRate_: 0
            });

            controllerModProxy = optionsControllerModProxy;
            viewer = new OptionViewer(vaultProxy);
        }

        // Can consider later enabling trade fees for all tests. Eg set it to 0.1% 0.001e18
        leverageModProxy.initialize({
            vault_: vaultProxy,
            marginMin_: 0.05e18,
            leverageMin_: 1.5e18,
            leverageMax_: 25e18
        });

        // Can consider later enabling trade fees for all tests. Eg set it to 0.5% 0.005e18
        stableModProxy.initialize(vaultProxy);

        oracleModProxy.initialize({owner_: admin, pythContract_: IPyth(address(mockPyth))});

        orderAnnouncementModProxy.initialize({
            vault_: vaultProxy,
            minDepositAmountUSD_: 1e18,
            minExecutabilityAge_: 10 seconds
        });
        orderExecutionModProxy.initialize({vault_: vaultProxy, maxExecutabilityAge_: 1 minutes});

        liquidationModProxy.initialize({
            vault_: vaultProxy,
            liquidationFeeRatio_: 0.005e18, // 0.5% liquidation fee
            liquidationBufferRatio_: 0.005e18, // 0.5% liquidation buffer
            liquidationFeeLowerBound_: 4e18, // 4 USD
            liquidationFeeUpperBound_: 100e18 // 100 USD
        });

        positionSplitterProxy.initialize(vaultProxy);

        // Set the oracle data for collateral and market token.
        // In the default setup both the collateral and market tokens are same.
        {
            OracleModuleStructs.OnchainOracle memory collateralOnchainOracle = OracleModuleStructs.OnchainOracle(
                collateralChainlinkAggregatorV3,
                25 * 60 * 60 // 25 hours for Chainlink oracle price to become stale
            );
            OracleModuleStructs.OffchainOracle memory collateralOffchainOracle = OracleModuleStructs.OffchainOracle(
                collateralPythId,
                60, // max age of 60 seconds
                1000
            );

            oracleModProxy.setOracles(address(collateralAsset), collateralOnchainOracle, collateralOffchainOracle);
            oracleModProxy.setMaxDiffPercent(address(collateralAsset), 1e18); // Disable max diff percent.
        }

        {
            FlatcoinVaultStructs.AuthorizedModule[]
                memory authorizedModules = new FlatcoinVaultStructs.AuthorizedModule[](8);

            authorizedModules[0] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: STABLE_MODULE_KEY,
                moduleAddress: address(stableModProxy)
            });
            authorizedModules[1] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: LEVERAGE_MODULE_KEY,
                moduleAddress: address(leverageModProxy)
            });
            authorizedModules[2] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: ORACLE_MODULE_KEY,
                moduleAddress: address(oracleModProxy)
            });
            authorizedModules[3] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: ORDER_ANNOUNCEMENT_MODULE_KEY,
                moduleAddress: address(orderAnnouncementModProxy)
            });
            authorizedModules[4] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: ORDER_EXECUTION_MODULE_KEY,
                moduleAddress: address(orderExecutionModProxy)
            });
            authorizedModules[5] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: LIQUIDATION_MODULE_KEY,
                moduleAddress: address(liquidationModProxy)
            });
            authorizedModules[6] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: CONTROLLER_MODULE_KEY,
                moduleAddress: address(controllerModProxy)
            });
            authorizedModules[7] = FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: POSITION_SPLITTER_MODULE_KEY,
                moduleAddress: address(positionSplitterProxy)
            });

            // Authorize the modules within the vault.
            vaultProxy.addAuthorizedModules(authorizedModules);
        }

        {
            address[] memory tokens = new address[](2);
            tokens[0] = address(0);
            tokens[1] = address(collateralAsset);

            fillWalletsWithTokens(tokens);
        }

        setCollateralPrice(1000e8);

        mockKeeperFee = IKeeperFee(
            address(
                new OPKeeperFee({
                    owner_: admin,
                    ethOracle_: address(collateralChainlinkAggregatorV3),
                    oracleModule_: address(oracleModProxy),
                    assetToPayWith_: address(collateral_),
                    profitMarginPercent_: 3e18,
                    keeperFeeUpperBound_: 50e18, // $50
                    keeperFeeLowerBound_: 0.25e18, // 25 cents
                    gasUnitsL1_: 30_000,
                    gasUnitsL2_: 1_200_000,
                    stalenessPeriod_: type(uint256).max / 2 // Effectively disable oracle expiry.
                })
            )
        );

        // Set the keeper fee module in the vault.
        vaultProxy.addAuthorizedModule(
            FlatcoinVaultStructs.AuthorizedModule({
                moduleKey: KEEPER_FEE_MODULE_KEY,
                moduleAddress: address(mockKeeperFee)
            })
        );

        setKeeperFeeMocks();
        setOracleMocks();

        vm.stopPrank();
    }

    /********************************************
     *             Helper Functions             *
     ********************************************/
    function fillWalletsWithTokens(address[] memory tokens) internal {
        for (uint i; i < tokens.length; ++i) {
            uint256 decimals = (tokens[i] != address(0)) ? IERC20Metadata(tokens[i]).decimals() : uint256(18);
            uint256 amount = 100_000 * (10 ** decimals);

            for (uint j; j < accounts.length; ++j) {
                // If address(0) is passed, deal the native token.
                if (tokens[i] == address(0)) deal(accounts[j], amount);
                else deal(tokens[i], accounts[j], amount);
            }
        }
    }

    function setCollateralPrice(uint256 price) public {
        skip(1);

        setPrice(price, collateralChainlinkAggregatorV3, collateralPythId);
        collateralAssetPrice = price * 1e10;
    }

    /// @dev Kept for backward compatibility.
    /// @dev Only useful when collateral and market tokens are the same (WETH Perp tests).
    function getPriceUpdateData(uint256 price) public view returns (bytes[] memory priceUpdateData) {
        return getPriceUpdateData(price, collateralPythId);
    }

    function getPriceUpdateData(uint256 price, bytes32 priceId) public view returns (bytes[] memory priceUpdateData) {
        priceUpdateData = new bytes[](1);
        priceUpdateData[0] = mockPyth.createPriceFeedUpdateData(
            priceId,
            int64(uint64(price)),
            uint64(price) / 10_000,
            -8,
            int64(uint64(price)),
            uint64(price) / 10_000,
            uint64(block.timestamp)
        );
    }

    function getPriceUpdateDataMultiple(
        PythPrice[] memory pythPrice
    ) public view returns (bytes[] memory priceUpdateData) {
        priceUpdateData = new bytes[](pythPrice.length);

        for (uint256 i; i < pythPrice.length; ++i) {
            uint256 price = pythPrice[i].price;
            bytes32 priceId = pythPrice[i].priceId;
            priceUpdateData[i] = mockPyth.createPriceFeedUpdateData(
                priceId,
                int64(uint64(price)),
                uint64(price) / 10_000,
                -8,
                int64(uint64(price)),
                uint64(price) / 10_000,
                uint64(block.timestamp)
            );
        }
    }

    function disableChainlinkExpiry() public {
        disableChainlinkExpiry(address(collateralAsset), collateralChainlinkAggregatorV3, collateralPythId);
    }

    function setPrice(uint256 price, IChainlinkAggregatorV3 chainLinkAggregatorV3, bytes32 priceId) public {
        vm.mockCall(
            address(chainLinkAggregatorV3),
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(0, price, 0, block.timestamp, 0)
        );

        // Update Pyth network price
        bytes[] memory priceUpdateData = getPriceUpdateData({price: price, priceId: priceId});
        oracleModProxy.updatePythPrice{value: 1}(keeper, priceUpdateData);
    }

    function disableChainlinkExpiry(
        address asset,
        IChainlinkAggregatorV3 chainlinkAggregatorV3,
        bytes32 priceId
    ) public {
        OracleModuleStructs.OnchainOracle memory onchainOracle = OracleModuleStructs.OnchainOracle(
            chainlinkAggregatorV3,
            type(uint32).max // Effectively disable oracle expiry.
        );
        OracleModuleStructs.OffchainOracle memory offchainOracle = OracleModuleStructs.OffchainOracle(
            priceId,
            60, // max age of 60 seconds
            1000
        );

        vm.startPrank(admin);

        oracleModProxy.setOracles({asset_: asset, onchainOracle_: onchainOracle, offchainOracle_: offchainOracle});
    }

    /// @dev Sets mock values for making the OP KeeperFee contract work.
    function setKeeperFeeMocks() public {
        address opGasPriceOracle = 0x420000000000000000000000000000000000000F;

        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.baseFee.selector),
            returnData: abi.encode(0)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.isEcotone.selector),
            returnData: abi.encode(true)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.l1BaseFee.selector),
            returnData: abi.encode(15384298693)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.baseFeeScalar.selector),
            returnData: abi.encode(2269)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.blobBaseFeeScalar.selector),
            returnData: abi.encode(1055762)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.blobBaseFee.selector),
            returnData: abi.encode(23276216517)
        });
        vm.mockCall({
            callee: opGasPriceOracle,
            data: abi.encodeWithSelector(IGasPriceOracle.decimals.selector),
            returnData: abi.encode(6)
        });
    }

    function setOracleMocks() internal {
        vm.mockCall({
            callee: address(collateralChainlinkAggregatorV3),
            data: abi.encodeWithSelector(IChainlinkAggregatorV3.decimals.selector),
            returnData: abi.encode(8)
        });
    }
}
