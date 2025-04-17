// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Setup.sol";

struct Token {
    IERC20 token;
    IChainlinkAggregatorV3 priceFeed;
}

abstract contract IntegrationSetup is Setup {
    using SafeERC20 for IERC20;

    // Fork config.
    string NETWORK_ALIAS;
    uint256 CHAIN_ID;
    uint256 BLOCK_NUMBER;

    // Router addresses.
    address ONE_INCH_ROUTER_V6;
    address ZEROX_ROUTER_V4;
    address PARASWAP_ROUTER_V5;
    address PARASWAP_ROUTER_V6;
    address ODOS_ROUTER_V2;

    // Permit2 related.
    address PERMIT2;
    bytes32 DOMAIN_SEPARATOR;

    // Token and Chainlink pricefeed addresses.
    Token USDC;
    Token DAI;
    Token rETH;
    Token WETH;

    // Function to fill wallets with tokens.
    // Can be overridden in the child contract to fill wallets with custom tokens.
    function fillWallets() internal virtual {
        address[] memory tokens = new address[](6);
        tokens[0] = address(USDC.token);
        tokens[1] = address(DAI.token);
        tokens[2] = address(rETH.token);
        tokens[4] = address(WETH.token);
        tokens[5] = address(0);

        // fillWalletWithTokens(alice, tokens);
        fillWalletsWithTokens(tokens);

        vm.startPrank(alice);

        // Approve the permit2 contract for all tokens.
        for (uint8 i; i < tokens.length; ++i) {
            if (tokens[i] != address(0)) IERC20(tokens[i]).safeIncreaseAllowance(PERMIT2, type(uint256).max);
        }
    }
}
