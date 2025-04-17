// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AggregatorsPriceCacheManager} from "./AggregatorsPriceCacheManager.sol";
import {Surl} from "../../script/utils/Surl.sol";
import "forge-std/console2.sol";

/// @dev Only supports Base network.
abstract contract AggregatorsAPIHelper is AggregatorsPriceCacheManager {
    using Surl for *;

    struct OneInchFunctionStruct {
        address holder;
        IERC20 srcToken;
        IERC20 destToken;
        uint256 srcAmount;
        uint8 slippage;
    }

    struct ZeroXFunctionStruct {
        IERC20 srcToken;
        IERC20 destToken;
        uint256 srcAmount;
        uint8 slippage;
    }

    struct ParaswapFunctionStruct {
        address user;
        address holder;
        IERC20 srcToken;
        IERC20 destToken;
        uint256 srcAmount;
        uint8 slippage;
        string version;
    }

    struct OdosFunctionStruct {
        address user;
        IERC20 srcToken;
        IERC20 destToken;
        uint256 srcAmount;
        uint8 slippage;
    }

    // APIs related constants
    uint8 constant RETRIES = 10;
    uint16 constant DEFAULT_HALT_MILLISECONDS = 2000;

    function __AggregatorsAPIHelper_init(bool useCachedSwapData_) public {
        __AggregatorsPriceCacheManager_init(useCachedSwapData_);
    }

    function getDataFromOneInchV6(
        OneInchFunctionStruct memory oneInchFunctionStruct
    ) internal returns (uint256 destAmount_, bytes memory calldata_) {
        {
            if (useCachedSwapData) {
                bool exists;
                (exists, destAmount_, calldata_) = checkAndGetSwapDatas(
                    oneInchFunctionStruct.srcToken,
                    oneInchFunctionStruct.destToken,
                    oneInchFunctionStruct.srcAmount,
                    Aggregator.ONE_INCH_V6
                );

                if (exists) {
                    return (destAmount_, calldata_);
                }
            }
        }

        string memory APIKey = vm.envString("ONEINCH_API_KEY");
        string[] memory headers = new string[](3);

        string memory url = string.concat(
            "https://api.1inch.dev/swap/v6.0/8453/swap?src=",
            vm.toString(address(oneInchFunctionStruct.srcToken)),
            "&dst=",
            vm.toString(address(oneInchFunctionStruct.destToken)),
            "&amount=",
            vm.toString(oneInchFunctionStruct.srcAmount),
            "&from=",
            vm.toString(oneInchFunctionStruct.holder),
            "&slippage=",
            vm.toString(oneInchFunctionStruct.slippage),
            "&disableEstimate=true"
        );

        headers[0] = string.concat("Authorization: Bearer ", APIKey);
        headers[1] = "accept: application/json";
        headers[2] = "content-type: application/json";

        (uint256 status, bytes memory data) = _fetchAndRetry(url, headers);

        if (status != 200) {
            console2.log("Status: ", status);
            console2.log("Data: ", string(data));

            revert("Failed to fetch data from 1inch API");
        }

        destAmount_ = vm.parseJsonUint(string(data), ".dstAmount");
        calldata_ = vm.parseJsonBytes(string(data), ".tx.data");

        if (useCachedSwapData) {
            appendNewObj(
                oneInchFunctionStruct.srcToken,
                oneInchFunctionStruct.destToken,
                oneInchFunctionStruct.srcAmount,
                destAmount_,
                Aggregator.ONE_INCH_V6,
                calldata_
            );
        }
    }

    function getDataFromZeroX(
        ZeroXFunctionStruct memory zeroXFunctionStruct
    ) internal returns (uint256 destAmount_, bytes memory calldata_) {
        string memory slippageString = convertSlippageToString(zeroXFunctionStruct.slippage, -2);

        return getDataFromZeroX(zeroXFunctionStruct, slippageString);
    }

    /// @dev `slippage` is a string as it's a number with only decimal places.
    ///       for example, 1% slippage is "0.01" and 100% slippage is "1.0".
    function getDataFromZeroX(
        ZeroXFunctionStruct memory zeroXFunctionStruct,
        string memory slippage
    ) internal returns (uint256 destAmount_, bytes memory calldata_) {
        {
            if (useCachedSwapData) {
                bool exists;
                (exists, destAmount_, calldata_) = checkAndGetSwapDatas(
                    zeroXFunctionStruct.srcToken,
                    zeroXFunctionStruct.destToken,
                    zeroXFunctionStruct.srcAmount,
                    Aggregator.ZERO_X
                );

                if (exists) {
                    return (destAmount_, calldata_);
                }
            }
        }

        string memory APIKey = vm.envString("ZEROX_API_KEY");
        string[] memory headers = new string[](3);

        string memory url = string.concat(
            "https://base.api.0x.org/swap/v1/quote?",
            "sellToken=",
            vm.toString(address(zeroXFunctionStruct.srcToken)),
            "&buyToken=",
            vm.toString(address(zeroXFunctionStruct.destToken)),
            "&sellAmount=",
            vm.toString(zeroXFunctionStruct.srcAmount),
            "&slippagePercentage=",
            slippage
        );

        headers[0] = string.concat("0x-api-key: ", APIKey);
        headers[1] = "accept: application/json";
        headers[2] = "content-type: application/json";

        (uint256 status, bytes memory data) = _fetchAndRetry(url, headers);

        if (status != 200) {
            console2.log("Status: ", status);
            console2.log("Data: ", string(data));

            revert("Failed to fetch data from 0x API");
        }

        destAmount_ = vm.parseJsonUint(string(data), ".buyAmount");
        calldata_ = vm.parseJsonBytes(string(data), ".data");

        if (useCachedSwapData) {
            appendNewObj(
                zeroXFunctionStruct.srcToken,
                zeroXFunctionStruct.destToken,
                zeroXFunctionStruct.srcAmount,
                destAmount_,
                Aggregator.ZERO_X,
                calldata_
            );
        }
    }

    function getDataFromParaswap(
        ParaswapFunctionStruct memory paraswapFunctionStruct
    ) internal returns (uint256 destAmount_, bytes memory calldata_) {
        Aggregator paraswapAggregatorVersion = (keccak256(abi.encodePacked(paraswapFunctionStruct.version)) ==
            keccak256(abi.encodePacked("5")))
            ? Aggregator.PARASWAP_V5
            : Aggregator.PARASWAP_V6;
        {
            if (useCachedSwapData) {
                bool exists;
                (exists, destAmount_, calldata_) = checkAndGetSwapDatas(
                    paraswapFunctionStruct.srcToken,
                    paraswapFunctionStruct.destToken,
                    paraswapFunctionStruct.srcAmount,
                    paraswapAggregatorVersion
                );

                if (exists) {
                    return (destAmount_, calldata_);
                }
            }
        }

        bytes memory priceRoute = _getPriceDataFromParaswap(
            paraswapFunctionStruct.srcToken,
            paraswapFunctionStruct.destToken,
            paraswapFunctionStruct.srcAmount,
            paraswapFunctionStruct.version
        );

        string memory body = string.concat(
            "{",
            '"srcToken":',
            '"',
            vm.toString(address(paraswapFunctionStruct.srcToken)),
            '"',
            ",",
            '"destToken":',
            '"',
            vm.toString(address(paraswapFunctionStruct.destToken)),
            '"',
            ",",
            '"srcAmount":',
            '"',
            vm.toString(paraswapFunctionStruct.srcAmount),
            '"',
            ",",
            '"userAddress":',
            '"',
            vm.toString(paraswapFunctionStruct.holder),
            '"',
            ",",
            '"txOrigin":',
            '"',
            vm.toString(paraswapFunctionStruct.user),
            '"',
            ",",
            '"slippage":',
            vm.toString(paraswapFunctionStruct.slippage),
            ",",
            '"priceRoute":',
            string(priceRoute),
            "}"
        );

        {
            string[] memory headers = new string[](2);
            headers[0] = "accept: application/json";
            headers[1] = "content-type: application/json";

            string memory url = "https://api.paraswap.io/transactions/8453?ignoreChecks=true";
            (uint256 status, bytes memory data) = _fetchAndRetry(url, headers, body);

            if (status != 200) {
                console2.log("Status: ", status);
                console2.log("Data: ", string(data));

                revert("Failed to fetch data from Paraswap API");
            }

            destAmount_ = vm.parseJsonUint(string(priceRoute), ".destAmount");
            calldata_ = vm.parseJsonBytes(string(data), ".data");
        }

        if (useCachedSwapData) {
            appendNewObj(
                paraswapFunctionStruct.srcToken,
                paraswapFunctionStruct.destToken,
                paraswapFunctionStruct.srcAmount,
                destAmount_,
                paraswapAggregatorVersion,
                calldata_
            );
        }
    }

    function getDataFromOdos(
        OdosFunctionStruct memory odosFunctionStruct
    ) internal returns (uint256 destAmount_, bytes memory calldata_) {
        {
            if (useCachedSwapData) {
                bool exists;
                (exists, destAmount_, calldata_) = checkAndGetSwapDatas(
                    odosFunctionStruct.srcToken,
                    odosFunctionStruct.destToken,
                    odosFunctionStruct.srcAmount,
                    Aggregator.ODOS_V2
                );

                if (exists) {
                    return (destAmount_, calldata_);
                }
            }
        }

        string memory quoteBody = string.concat(
            "{",
            '"chainId":',
            '"',
            "8453",
            '"',
            ",",
            '"inputTokens":',
            "[{",
            '"amount":',
            '"',
            vm.toString(odosFunctionStruct.srcAmount),
            '"',
            ",",
            '"tokenAddress":',
            '"',
            vm.toString(address(odosFunctionStruct.srcToken)),
            '"',
            "}]",
            ",",
            '"outputTokens":',
            "[{",
            '"proportion":',
            '"1"',
            ",",
            '"tokenAddress":',
            '"',
            vm.toString(address(odosFunctionStruct.destToken)),
            '"',
            "}]",
            ",",
            '"userAddr":',
            '"',
            vm.toString(odosFunctionStruct.user),
            '"',
            ",",
            '"compact":',
            "true",
            ",",
            '"slippageLimitPercent":',
            vm.toString(odosFunctionStruct.slippage),
            "}"
        );

        {
            string[] memory headers = new string[](2);
            headers[0] = "accept: application/json";
            headers[1] = "content-type: application/json";

            string memory url = "https://api.odos.xyz/sor/quote/v2";
            (uint256 status, bytes memory data) = _fetchAndRetry(url, headers, quoteBody);

            if (status != 200) {
                console2.log("Status: ", status);
                console2.log("Data: ", string(data));

                revert("Failed to fetch quote data from Odos API");
            }

            string[] memory outputTokenAmountArr = vm.parseJsonStringArray(string(data), ".outAmounts");
            destAmount_ = vm.parseUint(outputTokenAmountArr[0]);

            string memory transactionBody = string.concat(
                "{",
                '"pathId":',
                '"',
                vm.parseJsonString(string(data), ".pathId"),
                '"',
                ",",
                '"userAddr":',
                '"',
                vm.toString(odosFunctionStruct.user),
                '"',
                "}"
            );

            url = "https://api.odos.xyz/sor/assemble";
            (status, data) = _fetchAndRetry(url, headers, transactionBody);

            if (status != 200) {
                console2.log("Status: ", status);
                console2.log("Data: ", string(data));

                revert("Failed to fetch transaction data from Odos API");
            }

            calldata_ = vm.parseJsonBytes(string(data), ".transaction.data");
        }

        if (useCachedSwapData) {
            appendNewObj(
                odosFunctionStruct.srcToken,
                odosFunctionStruct.destToken,
                odosFunctionStruct.srcAmount,
                destAmount_,
                Aggregator.ODOS_V2,
                calldata_
            );
        }
    }

    function _getPriceDataFromParaswap(
        IERC20 srcToken,
        IERC20 destToken,
        uint256 srcAmount,
        string memory version
    ) private returns (bytes memory priceData) {
        string[] memory headers = new string[](2);

        string memory url = string.concat(
            "https://api.paraswap.io/prices?",
            "srcToken=",
            vm.toString(address(srcToken)),
            "&destToken=",
            vm.toString(address(destToken)),
            "&srcDecimals=",
            vm.toString(IERC20Metadata(address(srcToken)).decimals()),
            "&destDecimals=",
            vm.toString(IERC20Metadata(address(destToken)).decimals()),
            "&amount=",
            vm.toString(srcAmount),
            "&version=",
            version,
            "&side=SELL",
            "&network=8453"
        );

        headers[0] = "accept: application/json";
        headers[1] = "content-type: application/json";

        {
            (uint256 status, bytes memory returnData) = _fetchAndRetry(url, headers);

            if (status != 200) {
                console2.log("Status: ", status);
                console2.log("Data: ", string(returnData));

                revert("Failed to fetch price data from Paraswap API");
            }

            string[] memory inputs = new string[](3);

            inputs[0] = "bash";
            inputs[1] = "-c";
            inputs[2] = string.concat("echo '", string(returnData), "' | jq -c '.priceRoute'");

            bytes memory res = vm.ffi(inputs);

            return res;
        }
    }

    function _fetchAndRetry(
        string memory url,
        string[] memory headers
    ) internal returns (uint256 status, bytes memory data) {
        for (uint8 i; i < RETRIES; i++) {
            (status, data) = url.get(headers);
            if (status != 200) {
                vm.sleep(DEFAULT_HALT_MILLISECONDS * i); // Halts execution for 2 seconds the first time and increases by 2 seconds each time for `i` retries.
            } else {
                break;
            }
        }
    }

    function _fetchAndRetry(
        string memory url,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        for (uint8 i; i < RETRIES; i++) {
            (status, data) = url.post(headers, body);
            if (status != 200) {
                vm.sleep(DEFAULT_HALT_MILLISECONDS * i); // Halts execution for 2 seconds the first time and increases by 2 seconds each time for `i` retries.
            } else {
                break;
            }
        }
    }

    function convertSlippageToString(uint8 slippage, int8 expo) internal pure returns (string memory slippageString) {
        slippageString = "0.";

        for (int8 i = expo + 1; i < 0; ++i) {
            slippageString = string.concat(slippageString, "0");
        }

        slippageString = string.concat(slippageString, vm.toString(slippage));
    }
}
