// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AggregatorsAPIHelper} from "./AggregatorsAPIHelper.sol";

import {Surl} from "../../script/utils/Surl.sol";
import "forge-std/Test.sol";

contract AggregatorsPriceCacheManager is Test {
    enum Aggregator {
        ONE_INCH_V6,
        ZERO_X,
        PARASWAP_V5,
        PARASWAP_V6,
        ODOS_V2
    }

    bool internal useCachedSwapData;

    function __AggregatorsPriceCacheManager_init(bool useCachedSwapData_) public {
        useCachedSwapData = useCachedSwapData_;

        // If we don't want to use cached swap data or we don't want to cache swap data, return.
        // This is particularly useful for integration tests run in a CI's environment.
        if (!useCachedSwapData_) {
            return;
        }

        uint256 forkBlockNumber = vm.getBlockNumber();
        string memory cacheDirPath = getCacheDirectoryPath();
        string memory cacheFilePath = getCacheFilePath();

        // Create a directory if it doesn't exist.
        if (!vm.isDir(cacheDirPath)) {
            vm.createDir(cacheDirPath, false);
        } else if (vm.isFile(cacheFilePath)) {
            string memory jsonFile = vm.readFile(cacheFilePath);

            // If the file exists, check if the `forkBlockNumber` in the cache is same as the current `forkBlockNumber_`
            if (
                vm.keyExistsJson(jsonFile, ".forkBlockNumber") &&
                forkBlockNumber == vm.parseJsonUint(jsonFile, ".forkBlockNumber")
            ) {
                return;
            }
        }

        // Create a JSON with block number as key.
        string memory key = "new-cache";
        string memory output = vm.serializeUint(key, "forkBlockNumber", forkBlockNumber);

        vm.writeFile(cacheFilePath, output);
    }

    function appendNewObj(
        IERC20 srcToken,
        IERC20 destToken,
        uint256 srcAmount,
        uint256 destAmount,
        Aggregator aggregator,
        bytes memory swapData
    ) internal {
        string memory key = getKey(srcToken, destToken, srcAmount, aggregator);
        string memory obj = getObjToAppend(srcToken, destToken, srcAmount, destAmount, aggregator, swapData);
        string memory cacheJson = getCacheJson();

        string memory oldKey = "old-key";
        vm.serializeJson(oldKey, cacheJson);

        string memory output = vm.serializeJson(key, obj);

        string memory newCacheJson = vm.serializeString(oldKey, key, output);
        string memory filePath = getCacheFilePath();

        vm.writeFile(filePath, newCacheJson);
    }

    function getObjToAppend(
        IERC20 srcToken,
        IERC20 destToken,
        uint256 srcAmount,
        uint256 destAmount,
        Aggregator aggregator,
        bytes memory swapData
    ) internal returns (string memory obj) {
        string memory newKey = "new-key";

        vm.serializeAddress(newKey, "srcToken", address(srcToken));
        vm.serializeAddress(newKey, "destToken", address(destToken));
        vm.serializeUint(newKey, "srcAmount", srcAmount);
        vm.serializeUint(newKey, "destAmount", destAmount);
        vm.serializeUint(newKey, "aggregator", uint256(aggregator));
        string memory finalOutput = vm.serializeBytes(newKey, "swapData", swapData);

        return finalOutput;
    }

    function checkAndGetSwapDatas(
        IERC20 srcToken,
        IERC20 destToken,
        uint256 srcAmount,
        Aggregator aggregator
    ) internal view returns (bool exists, uint256 destAmount, bytes memory swapData) {
        string memory key = getKey(srcToken, destToken, srcAmount, aggregator);
        string memory cacheJson = getCacheJson();

        exists = vm.keyExistsJson(cacheJson, string.concat(".", key));

        if (exists) {
            destAmount = vm.parseJsonUint(cacheJson, string.concat(".", key, ".destAmount"));
            swapData = vm.parseJsonBytes(cacheJson, string.concat(".", key, ".swapData"));
        }
    }

    function getCacheJson() internal view returns (string memory json) {
        string memory filePath = getCacheFilePath();

        return vm.readFile(filePath);
    }

    function getKey(
        IERC20 srcToken,
        IERC20 destToken,
        uint256 srcAmount,
        Aggregator aggregator
    ) internal pure returns (string memory key) {
        return vm.toString(keccak256(abi.encodePacked(srcToken, destToken, srcAmount, aggregator)));
    }

    function getCacheFilePath() internal view returns (string memory filePath) {
        return string.concat(getCacheDirectoryPath(), vm.toString(block.chainid), ".json");
    }

    function getCacheDirectoryPath() internal pure returns (string memory directoryPath) {
        return "swapdatas-cache/";
    }
}
