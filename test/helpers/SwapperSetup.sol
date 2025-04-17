// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IChainlinkAggregatorV3} from "../../src/interfaces/IChainlinkAggregatorV3.sol";

import "./IntegrationSetup.sol";
import {Swapper} from "../../src/misc/Swapper/Swapper.sol";
import {IWETH} from "../../src/interfaces/IWETH.sol";
import {AggregatorsPriceCacheManager} from "./AggregatorsPriceCacheManager.sol";
import "forge-std/Test.sol";

abstract contract SwapperSetup is IntegrationSetup {
    // Router keys.
    bytes32 constant ONE_INCH_V6_ROUTER_KEY = bytes32("ONE_INCH");
    bytes32 constant ZEROX_ROUTER_KEY = bytes32("ZERO_X");
    bytes32 constant PARASWAP_V5_ROUTER_KEY = bytes32("PARASWAP");
    bytes32 constant PARASWAP_V6_ROUTER_KEY = bytes32("PARASWAP_V6");
    bytes32 constant ODOS_V2_ROUTER_KEY = bytes32("ODOS_V2");

    uint8 constant DEFAULT_SLIPPAGE = 1; // 1%
    uint8 constant TRANSFER_METHODS = 3; // Number of `TransferMethod` available. Refer to `SwapperStructs.TransferMethod`. Don't use the below technique to get the number of enum values.
    uint8 constant TOTAL_AGGREGATORS = uint8(type(AggregatorsPriceCacheManager.Aggregator).max) + 1; // Number of aggregators available. Refer to `Aggregator`.
    uint256 internal DEFAULT_AMOUNT = 250; // Can be converted to any token amount based on the token's decimals.

    Swapper internal swapperProxy;
    address internal swapperImplementation;

    function setUp() public virtual override {
        // If `BLOCK_NUMBER` is not 0 then we need to use cached state.
        (BLOCK_NUMBER != 0) ? vm.createSelectFork(NETWORK_ALIAS, BLOCK_NUMBER) : vm.createSelectFork(NETWORK_ALIAS);
        vm.chainId(CHAIN_ID);

        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        accounts.push(alice);

        vm.startPrank(admin);
        proxyAdmin = new ProxyAdmin(admin);

        (bool success, bytes memory data) = PERMIT2.staticcall(abi.encodeWithSignature("DOMAIN_SEPARATOR()"));
        require(success, "Failed to fetch DOMAIN_SEPARATOR");

        DOMAIN_SEPARATOR = abi.decode(data, (bytes32));

        swapperImplementation = address(new Swapper());
        swapperProxy = Swapper(
            address(
                new TransparentUpgradeableProxy(
                    swapperImplementation,
                    address(proxyAdmin),
                    abi.encodeCall(Swapper.initialize, (admin, PERMIT2, IWETH(address(WETH.token))))
                )
            )
        );

        vm.label(address(swapperProxy), "Swapper");

        // Add routers to the whitelist.
        swapperProxy.addRouter(ONE_INCH_V6_ROUTER_KEY, ONE_INCH_ROUTER_V6);
        swapperProxy.addRouter(ZEROX_ROUTER_KEY, ZEROX_ROUTER_V4);
        swapperProxy.addRouter(PARASWAP_V5_ROUTER_KEY, PARASWAP_ROUTER_V5);
        swapperProxy.addRouter(PARASWAP_V6_ROUTER_KEY, PARASWAP_ROUTER_V6);
        swapperProxy.addRouter(ODOS_V2_ROUTER_KEY, ODOS_ROUTER_V2);

        fillWallets();
    }
}
