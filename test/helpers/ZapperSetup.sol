// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import "./Setup.sol";
import "./SwapperTestsHelper.sol";
import "./OrderHelpers.sol";

import {FlatZapper} from "../../src/misc/FlatZapper/FlatZapper.sol";

abstract contract ZapperSetup is Setup, SwapperTestsHelper, OrderHelpers {
    address internal zapperImplementation;
    FlatZapper internal zapperProxy;

    function setUp() public virtual override(Setup, SwapperTestsHelper) {
        // Collateral setup
        {
            collateralAsset = MockERC20(address(rETH.token));
            collateralChainlinkAggregatorV3 = IChainlinkAggregatorV3(address(rETH.priceFeed));
            vm.label(address(collateralAsset), "RETH");
        }

        SwapperTestsHelper.setUp();
        Setup.setUpWithController({collateral_: collateralAsset, controller_: ControllerType.PERP});

        vm.startPrank(admin);

        zapperImplementation = address(new FlatZapper());
        zapperProxy = FlatZapper(
            address(
                new TransparentUpgradeableProxy(
                    zapperImplementation,
                    address(proxyAdmin),
                    abi.encodeCall(
                        FlatZapper.initialize,
                        (
                            admin,
                            vaultProxy,
                            IERC20(address(collateralAsset)),
                            swapperProxy,
                            address(orderAnnouncementModProxy),
                            PERMIT2,
                            IWETH(address(WETH.token))
                        )
                    )
                )
            )
        );

        vm.label(address(zapperProxy), "FlatZapper");

        // Authorize the zapper contract in the OrderAnnouncementModule to create
        // orders on behalf of other addresses.
        orderAnnouncementModProxy.addAuthorizedCaller(address(zapperProxy));
    }
}
