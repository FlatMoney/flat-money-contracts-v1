// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IFlatcoinVault} from "../../interfaces/IFlatcoinVault.sol";
import {ISwapper} from "../../interfaces/ISwapper.sol";

abstract contract FlatZapperStorage {
    // @custom:storage-location erc7201:FlatZapper
    struct FlatZapperStorageData {
        IERC20 collateral;
        IFlatcoinVault vault;
        ISwapper swapper;
    }

    // keccak256(abi.encode(uint256(keccak256("FlatZapper")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _FLATZAPPER_STORAGE_LOCATION =
        0xd864549198ec95d704c0a8cce160d13cbd5509cdd8c7e567bb2b8fe66fc5ce00;

    // solhint-disable-next-line func-name-mixedcase
    function __FlatZapperStorage_init(IERC20 collateral_, IFlatcoinVault vault_, ISwapper swapper_) internal {
        FlatZapperStorageData storage zapperStorage = _getFlatZapperStorage();

        zapperStorage.collateral = collateral_;
        zapperStorage.vault = vault_;
        zapperStorage.swapper = swapper_;
    }

    function getCollateral() public view returns (IERC20 collateral_) {
        return _getFlatZapperStorage().collateral;
    }

    function getVault() public view returns (IFlatcoinVault vault_) {
        return _getFlatZapperStorage().vault;
    }

    function getSwapper() public view returns (ISwapper swapper_) {
        return _getFlatZapperStorage().swapper;
    }

    function _setVault(IFlatcoinVault vault_) internal {
        _getFlatZapperStorage().vault = vault_;
    }

    function _setCollateral(IERC20 collateral_) internal {
        _getFlatZapperStorage().collateral = collateral_;
    }

    function _setSwapper(ISwapper swapper_) internal {
        _getFlatZapperStorage().swapper = swapper_;
    }

    function _getFlatZapperStorage() private pure returns (FlatZapperStorageData storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _FLATZAPPER_STORAGE_LOCATION
        }
    }
}
