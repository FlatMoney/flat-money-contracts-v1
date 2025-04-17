// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IntegrationSetup} from "../../helpers/IntegrationSetup.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChainlinkAggregatorV3} from "../../../src/interfaces/IChainlinkAggregatorV3.sol";
import {Token} from "../../helpers/IntegrationSetup.sol";

abstract contract Setup8453 is IntegrationSetup {
    constructor() {
        // Fork config.
        NETWORK_ALIAS = "base";
        CHAIN_ID = 8453;
        BLOCK_NUMBER = 28415419;

        // Router addresses on Base mainnet.
        ONE_INCH_ROUTER_V6 = 0x111111125421cA6dc452d289314280a0f8842A65;
        ZEROX_ROUTER_V4 = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;
        PARASWAP_ROUTER_V5 = 0x59C7C832e96D2568bea6db468C1aAdcbbDa08A52;
        PARASWAP_ROUTER_V6 = 0x6A000F20005980200259B80c5102003040001068;
        ODOS_ROUTER_V2 = 0x19cEeAd7105607Cd444F5ad10dd51356436095a1;

        // Permit2 related.
        PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

        // Token addresses on Base mainnet.
        USDC = Token({
            token: IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
            priceFeed: IChainlinkAggregatorV3(0x7e860098F58bBFC8648a4311b374B1D669a2bc6B)
        });
        DAI = Token({
            token: IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb),
            priceFeed: IChainlinkAggregatorV3(0x591e79239a7d679378eC8c847e5038150364C78F)
        });
        rETH = Token({
            token: IERC20(0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c),
            priceFeed: IChainlinkAggregatorV3(0xbe1551fB22F8b877EDF3731CEc6FF703E720Fb85)
        });
        WETH = Token({
            token: IERC20(0x4200000000000000000000000000000000000006),
            priceFeed: IChainlinkAggregatorV3(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70)
        });
    }
}
