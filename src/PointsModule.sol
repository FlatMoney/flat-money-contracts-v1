// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ModuleUpgradeable} from "./abstracts/ModuleUpgradeable.sol";
import {DecimalMath} from "./libraries/DecimalMath.sol";
import {FlatcoinErrors} from "./libraries/FlatcoinErrors.sol";
import {FlatcoinModuleKeys} from "./libraries/FlatcoinModuleKeys.sol";
import {FlatcoinStructs} from "./libraries/FlatcoinStructs.sol";
import {ERC20LockableUpgradeable} from "./misc/ERC20LockableUpgradeable.sol";

import {IFlatcoinVault} from "./interfaces/IFlatcoinVault.sol";

/// @title PointsModule
/// @author dHEDGE
/// @notice Module for awarding points as an incentive.
contract PointsModule is ModuleUpgradeable, ERC20LockableUpgradeable {
    using SafeCast for uint256;
    using DecimalMath for uint256;
    using Math for uint64;

    struct MintPoints {
        address to;
        uint256 amount;
    }

    address public treasury;

    /// @notice The duration of the unlock tax vesting period
    uint256 public unlockTaxVest;

    /// @notice Used to calculate points to mint when a user opens a leveraged position
    uint256 public pointsPerSize;

    /// @notice Used to calculate points to mint when a user deposits an amount of collateral to the flatcoin
    uint256 public pointsPerDeposit;

    /// @notice Time when user’s points will have 0% unlock tax
    mapping(address account => uint256 unlockTime) public unlockTime;

    /// @notice The state and settings for rate limiting points minted from trading rewards
    FlatcoinStructs.MintRate public mintRate;

    uint256 public minMintAmount; // not constant in case we decide to change it in the future

    /// @dev To prevent the implementation contract from being used, we invoke the _disableInitializers
    ///      function in the constructor to automatically lock it when it is deployed.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Function to initialize this contract.
    function initialize(
        IFlatcoinVault _flatcoinVault,
        address _treasury,
        uint256 _unlockTaxVest,
        uint256 _pointsPerSize,
        uint256 _pointsPerDeposit,
        uint256 _mintRateMaxAccumulated,
        uint64 _mintRateDecayTime
    ) external initializer {
        if (address(_flatcoinVault) == address(0)) revert FlatcoinErrors.ZeroAddress("flatcoinVault");

        __Module_init(FlatcoinModuleKeys._POINTS_MODULE_KEY, _flatcoinVault);
        __ERC20_init("Flat Money Points", "FMP");

        setTreasury(_treasury);
        setPointsVest(_unlockTaxVest);
        setPointsMint(_pointsPerSize, _pointsPerDeposit);
        setMintRate(_mintRateMaxAccumulated, _mintRateDecayTime);
        minMintAmount = 1e6;
    }

    /////////////////////////////////////////////
    //         Public Write Functions          //
    /////////////////////////////////////////////

    /// @notice Mints locked points to the user account when a user opens a leveraged position (uses pointsPerSize).
    ///         The points start a 12 month unlock tax (update unlockTime).
    /// @dev The function will not revert if no points are minted because it's called by the flatcoin contracts.
    function mintLeverageOpen(address to, uint256 size) external onlyAuthorizedModule {
        if (pointsPerSize == 0) return; // no incentives set on leverage open

        uint256 amount = size._multiplyDecimal(pointsPerSize);
        uint256 amountToMint = _updateAccumulatedMint(amount);

        _mintTo(to, amountToMint);
    }

    /// @notice Mints locked points to the user account when a user deposits to the flatcoin (uses pointsPerDeposit).
    ///         The points start a 12 month unlock tax (update unlockTime).
    /// @dev The function will not revert if no points are minted because it's called by the flatcoin contracts.
    function mintDeposit(address to, uint256 depositAmount) external onlyAuthorizedModule {
        if (pointsPerDeposit == 0) return; // no incentives set on flatcoin LP deposit

        uint256 amount = depositAmount._multiplyDecimal(pointsPerDeposit);
        uint256 amountToMint = _updateAccumulatedMint(amount);

        _mintTo(to, amountToMint);
    }

    /// @notice Unlocks all of sender’s locked tokens. Sends any taxed points to the treasury.
    function unlockAll() public {
        _unlock(type(uint256).max);
    }

    /// @notice Unlocks a specified amount of the sender’s locked tokens. Sends any taxed points to the treasury.
    function unlock(uint256 amount) public {
        _unlock(amount);
    }

    /////////////////////////////////////////////
    //             View Functions              //
    /////////////////////////////////////////////

    /// @notice Calculates the unlock tax for a specific account.
    ///         If a user has 100 points that have vested for 6 months (50% tax), then it returns 0.5e18.
    ///         If this user earns another 100 points, then the new unlock tax should be 75% or 0.75e18.
    ///         This tax can be calculated by using and modifying the unlockTime when the points are minted to an account.
    function getUnlockTax(address account) public view returns (uint256 unlockTax) {
        if (unlockTime[account] <= block.timestamp) return 0;

        uint256 timeLeft = unlockTime[account] - block.timestamp;

        unlockTax = timeLeft._divideDecimal(unlockTaxVest);

        if (unlockTax > 1e18) unlockTax = 1e18; // could happen if the unlockTaxVest is decreased by owner
    }

    /// @notice Returns an account's locked token balance
    function lockedBalance(address account) public view returns (uint256 amount) {
        return _lockedAmount[account];
    }

    function getAccumulatedMint() public view returns (uint256 accumulatedMintAmount) {
        return ((mintRate.lastAccumulatedMint *
            ((mintRate.decayTime - mintRate.decayTime.min(block.timestamp - mintRate.lastMintTimestamp)))) /
            mintRate.decayTime);
    }

    function getAvailableMint() public view returns (uint256 availableMintAmount) {
        uint256 accumulatedMint = getAccumulatedMint();
        uint256 maxAccumulatedMint = mintRate.maxAccumulatedMint;

        if (accumulatedMint >= maxAccumulatedMint) return 0;

        return maxAccumulatedMint - accumulatedMint;
    }

    /////////////////////////////////////////////
    //           Internal Functions            //
    /////////////////////////////////////////////

    /// @notice Sets the unlock time for newly minted points.
    /// @dev    If the user has existing locked points, then the new unlock time is calculated based on the existing locked points.
    ///         The newly minted points are included in the `lockedAmount` calculation.
    function _setMintUnlockTime(address account, uint256 mintAmount) internal {
        uint256 lockedAmount = _lockedAmount[account];
        uint256 unlockTimeBefore = unlockTime[account];

        uint256 newUnlockTime;
        if (unlockTimeBefore <= block.timestamp) {
            newUnlockTime = block.timestamp + unlockTaxVest;
        } else {
            uint256 newUnlockTimeAmount = (block.timestamp + unlockTaxVest) * mintAmount;
            uint256 oldUnlockTimeAmount = unlockTimeBefore * (lockedAmount - mintAmount);
            newUnlockTime = (newUnlockTimeAmount + oldUnlockTimeAmount) / lockedAmount;
        }

        unlockTime[account] = newUnlockTime;
    }

    function _mintTo(address to, uint256 amount) internal {
        // Ignore dust amounts. It avoids potential precision errors on unlock time calculations
        if (amount < minMintAmount) return;

        uint256 _unlockTime = unlockTime[to];

        if (_unlockTime > 0 && _unlockTime <= block.timestamp) {
            // lock has expired, so unlock existing tokens first
            _unlock(to, _lockedAmount[to]);
        }
        _mint(to, amount);
        _lock(to, amount);
        _setMintUnlockTime(to, amount);
    }

    /// @notice Unlocks the sender’s locked tokens.
    function _unlock(uint256 amount) internal {
        uint256 unlockTax = getUnlockTax(msg.sender);
        uint256 lockedAmount = _lockedAmount[msg.sender];

        if (amount == type(uint256).max) amount = lockedAmount;

        if (lockedAmount == amount) unlockTime[msg.sender] = 0;

        _unlock(msg.sender, amount);

        if (unlockTax > 0) {
            uint256 treasuryAmount = amount._multiplyDecimal(unlockTax);
            _transfer(msg.sender, treasury, treasuryAmount);
        }
    }

    /// @notice Update the accumulated points mint
    /// @dev It will only update the accumulated mint if it is within the rate limit
    function _updateAccumulatedMint(uint256 _mintAmount) internal returns (uint256 _amountToMint) {
        uint256 newAccumulatedMint = _mintAmount + getAccumulatedMint();

        if (newAccumulatedMint > mintRate.maxAccumulatedMint) {
            _amountToMint = getAvailableMint();
            mintRate.lastAccumulatedMint = mintRate.maxAccumulatedMint;
        } else {
            _amountToMint = _mintAmount;
            mintRate.lastAccumulatedMint = newAccumulatedMint;
        }
        mintRate.lastMintTimestamp = block.timestamp.toUint64();
    }

    /////////////////////////////////////////////
    //             Owner Functions             //
    /////////////////////////////////////////////

    /// @notice Owner can mint points to any account. This can be used to distribute points to competition winners and other reward incentives.
    ///         The points start a 12 month unlock tax (update unlockTime).
    function mintTo(MintPoints calldata _mintPoints) external onlyOwner {
        _mintTo(_mintPoints.to, _mintPoints.amount);
    }

    /// @notice Owner can mint points to multiple accounts
    function mintToMultiple(MintPoints[] calldata _mintPoints) external onlyOwner {
        for (uint256 i = 0; i < _mintPoints.length; i++) {
            _mintTo(_mintPoints[i].to, _mintPoints[i].amount);
        }
    }

    /// @notice Sets the treasury address
    function setTreasury(address _treasury) public onlyOwner {
        if (_treasury == address(0)) revert FlatcoinErrors.ZeroAddress("treasury");

        treasury = _treasury;
    }

    /// @notice Sets the minted points per trade
    /// @dev There are no restrictions on the settings
    /// @param _pointsPerSize Used to calculate points to mint when a user opens a leveraged position
    /// @param _pointsPerDeposit Used to calculate points to mint when a user deposits an amount of collateral to the flatcoin
    function setPointsMint(uint256 _pointsPerSize, uint256 _pointsPerDeposit) public onlyOwner {
        pointsPerSize = _pointsPerSize;
        pointsPerDeposit = _pointsPerDeposit;
    }

    /// @notice CHANGING THE VEST TIME CAN HAVE UNINTENDED CONSEQUENCES
    ///         Limited to 10% per change. It sets the points unlock tax vesting period
    ///         Can be set to zero or any arbitrary value until non-zero value is set
    /// @dev Changing the vest period will skew the unlock period for existing locked points
    ///      Decreasing the period will delay the unlock ramp for existing locked points
    ///      Increasing the period will speed up the unlock ramp for existing locked points (immediately unlock more points)
    /// @param _unlockTaxVest The duration of the unlock tax vesting period
    function setPointsVest(uint256 _unlockTaxVest) public onlyOwner {
        if (unlockTaxVest > 0) {
            if (_unlockTaxVest > (unlockTaxVest * 1.1e18) / 1e18)
                revert FlatcoinErrors.MaxVarianceExceeded("unlockTaxVest");
            if (_unlockTaxVest < (unlockTaxVest * 0.9e18) / 1e18)
                revert FlatcoinErrors.MaxVarianceExceeded("unlockTaxVest");
            if (_unlockTaxVest == 0) revert FlatcoinErrors.ZeroValue("unlockTaxVest"); // setting to 0 might break some math
        }

        unlockTaxVest = _unlockTaxVest;
    }

    /// @notice Sets the points mint rate limiting settings.
    /// @dev Mint rate limits only apply to points minted by trading.
    function setMintRate(uint256 _maxAccumulatedMint, uint64 _decayTime) public onlyOwner {
        mintRate.decayTime = _decayTime;
        mintRate.maxAccumulatedMint = _maxAccumulatedMint;
    }
}
