// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @title ERC20LockableUpgradeable
/// @author dHEDGE
/// @notice An abstract contract to create an ERC20 token which can be locked and unlocked as per
///         the inheriting contract's requirements.
// solhint-disable reason-string
// solhint-disable gas-custom-errors
abstract contract ERC20LockableUpgradeable is ERC20Upgradeable {
    mapping(address account => uint256 lockedAmount) internal _lockedAmount;

    event Locked(address indexed account, uint256 amount);
    event Unlocked(address indexed account, uint256 amount);

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20LockableUpgradeable_init()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    // solhint-disable-next-line func-name-mixedcase
    function __ERC20LockableUpgradeable_init_unchained()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    function _lock(address account_, uint256 amount_) internal virtual {
        require(
            _lockedAmount[account_] + amount_ <= balanceOf(account_),
            "ERC20LockableUpgradeable: locked amount exceeds balance"
        );

        _lockedAmount[account_] += amount_;
        emit Locked(account_, amount_);
    }

    function _unlock(address account_, uint256 amount_) internal virtual {
        require(
            _lockedAmount[account_] >= amount_,
            "ERC20LockableUpgradeable: requested unlock exceeds locked balance"
        );

        _lockedAmount[account_] -= amount_;

        emit Unlocked(account_, amount_);
    }

    function _update(address from_, address to_, uint256 amount_) internal virtual override {
        // Make sure the sender has enough unlocked tokens.
        // Note: the below requirement is not needed when minting tokens in which case the `from` address is 0x0.
        if (from_ != address(0)) {
            require(
                balanceOf(from_) - _lockedAmount[from_] >= amount_,
                "ERC20LockableUpgradeable: insufficient unlocked balance"
            );
        }

        super._update(from_, to_, amount_);
    }

    uint256[49] private __gap;
}
