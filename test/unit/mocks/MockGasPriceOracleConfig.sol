// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

contract MockGasPriceOracleConfig {
    // Snapshot of variables from the public Base Mainnet gas price oracle contract.
    // Gas price oracle contract address: `0x420000000000000000000000000000000000000F`.
    uint256 public gasPrice = 0;
    uint256 public baseFee = 0;
    uint256 public overhead = 0;
    uint256 public l1BaseFee = 29244622388;
    uint256 public decimals = 6;
    uint256 public scalar = 0;
    uint256 public blobBaseFee = 1;
    uint32 public blobBaseFeeScalar = 659851;
    uint32 public baseFeeScalar = 1101;
    bool public isEcotone = true;
}
