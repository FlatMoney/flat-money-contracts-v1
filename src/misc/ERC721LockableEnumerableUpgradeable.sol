// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

// solhint-disable reason-string
// solhint-disable gas-custom-errors
contract ERC721LockableEnumerableUpgradeable is ERC721EnumerableUpgradeable {
    struct LockData {
        uint8 lockCount;
        mapping(bytes32 moduleKeys => bool locked) lockedByModule;
    }

    /// @dev Mapping which holds the lock status of each token ID.
    ///      A `tokenId` is locked if the `lockData.lockCount` value is greater than 0.
    mapping(uint256 tokenId => LockData lockData) internal _lockCounter;

    event Locked(uint256 indexed tokenId, bytes32 indexed moduleKey);
    event Unlocked(uint256 indexed tokenId, bytes32 indexed moduleKey);
    event UnlockedAllLocks(uint256 tokenId, bytes32 indexed moduleKey);

    // solhint-disable-next-line func-name-mixedcase
    function __ERC721LockableEnumerableUpgradeable_init()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    // solhint-disable-next-line func-name-mixedcase
    function __ERC721LockableEnumerableUpgradeable_init_unchained()
        internal
        onlyInitializing // solhint-disable-next-line no-empty-blocks
    {}

    /// @notice Function to lock a token ID.
    /// @dev Note that this function doesn't revert if the token ID is already locked.
    /// @dev  Some important notes about the lock mechanism:
    ///       - Multiple modules can lock the same token ID, but the token ID will only be unlocked when all modules unlock it.
    ///       - Each time a module calls `lock`, the `lockCount` is incremented by 1 only if the module hasn't locked the token ID before.
    /// @dev Warning: This function doesn't check the caller is the owner of the token. That's why this should only be used by trusted modules.
    ///      which contain the check for the same.
    /// @param tokenId The ERC721 token ID to lock.
    function _lock(uint256 tokenId, bytes32 moduleKey) internal virtual {
        require(
            !_lockCounter[tokenId].lockedByModule[moduleKey],
            "ERC721LockableEnumerableUpgradeable: token is already locked by this module"
        );

        ++_lockCounter[tokenId].lockCount;
        _lockCounter[tokenId].lockedByModule[moduleKey] = true;

        emit Locked(tokenId, moduleKey);
    }

    /// @notice Function to unlock a token ID.
    /// @dev Note that this function doesn't revert if the token ID is already unlocked.
    /// @dev Warning: This function doesn't check the caller is the owner of the token. That's why this should only be used by trusted modules.
    ///      which contain the check for the same.
    /// @param tokenId The ERC721 token ID to unlock.
    function _unlock(uint256 tokenId, bytes32 moduleKey) internal virtual {
        require(_lockCounter[tokenId].lockCount > 0, "ERC721LockableEnumerableUpgradeable: token is already unlocked");
        require(
            _lockCounter[tokenId].lockedByModule[moduleKey],
            "ERC721LockableEnumerableUpgradeable: token is not locked by this module"
        );

        --_lockCounter[tokenId].lockCount;
        _lockCounter[tokenId].lockedByModule[moduleKey] = false;

        emit Unlocked(tokenId, moduleKey);
    }

    /// @notice Function to clear all locks of a token ID.
    /// @dev Warning: This function should only be used before burning the token.
    /// @dev This function doesn't check if there are any locks or not as there is no point in doing so as we are going to clear all locks anyway.
    /// @dev We just emit the `moduleKey` which called this function for tracking purposes.
    function _clearAllLocks(uint256 tokenId, bytes32 moduleKey) internal virtual {
        _lockCounter[tokenId].lockCount = 0;

        emit UnlockedAllLocks(tokenId, moduleKey);
    }

    /// @notice Before token transfer hook.
    /// @dev Reverts if the token is locked. Make sure that when minting/burning a token it is unlocked.
    /// @param to The address to transfer tokens to.
    /// @param tokenId The ERC721 token ID to transfer.
    /// @param auth See OZ _update function.
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address from) {
        // Make sure the token is not locked.
        require(_lockCounter[tokenId].lockCount == 0, "ERC721LockableEnumerableUpgradeable: token is locked");

        return super._update(to, tokenId, auth);
    }

    uint256[49] private __gap;
}
