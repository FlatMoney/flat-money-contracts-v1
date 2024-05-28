// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IGasPriceOracle {
    function baseFee() external view returns (uint256 _baseFee);

    function baseFeeScalar() external view returns (uint32 _baseFeeScalar);

    function blobBaseFee() external view returns (uint256 _blobBaseFee);

    function blobBaseFeeScalar() external view returns (uint32 _blobBaseFeeScalar);

    function decimals() external pure returns (uint256 _decimals);

    function gasPrice() external view returns (uint256 _gasPrice);

    function getL1Fee(bytes memory _data) external view returns (uint256 _l1Fee);

    function getL1GasUsed(bytes memory _data) external view returns (uint256 _l1GasUsed);

    function isEcotone() external view returns (bool _isEcotone);

    function l1BaseFee() external view returns (uint256 _l1BaseFee);

    function overhead() external view returns (uint256 _overhead);

    function scalar() external view returns (uint256 _scalar);

    function setEcotone() external;

    function version() external view returns (string memory _version);
}
