// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';

import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';
import { IVault } from './Vault.sol';
import { IwstETH } from './interfaces/lido/IwstETH.sol';
import { IRedemptionController } from './RedemptionController.sol';
import './libs/Rescuable.sol';

interface ITreehouseRedemptionV2 {
  error MinimumNotMet();
  error RedemptionNotFound();
  error InWaitingPeriod();
  error InsufficientFundsInVault();
  error RedemptionError();
  error FeeExceeded();

  event Redeemed(address indexed user, uint shares, uint assets);
  event RedeemFinalized(address indexed user, uint assets, uint fee);
  event WaitingPeriodUpdated(uint32 latest, uint32 old);
  event MinRedeemUpdated(uint128 latest, uint128 old);
  event RedemptionFeeUpdated(uint32 latest, uint32 old);

  struct RedemptionInfo {
    uint64 startTime;
    uint96 shares;
    uint128 assets;
    uint128 baseRate;
  }
}

/**
 * @notice Facilitate redemption of tAssets
 */
contract TreehouseRedemptionV2 is ITreehouseRedemptionV2, Ownable2Step, ReentrancyGuard, Pausable, Rescuable {
  using SafeERC20 for IERC20;
  using SafeCast for uint;
  uint32 PRECISION = 1e4;

  address public immutable IAU;
  address public immutable TASSET;
  IVault public immutable VAULT;
  IRedemptionController public immutable REDEMPTION_CONTROLLER;

  uint96 public minRedeemInUnderlying = 250 ether;
  uint32 public waitingPeriod = 7 days;
  uint96 public totalRedeeming;
  uint32 public redemptionFee;

  mapping(address => RedemptionInfo[]) private redemptionInfo;
  mapping(address => uint) public redeeming;

  constructor(address _creator, IVault _vault, IRedemptionController _redemptionController) Ownable(_creator) {
    VAULT = _vault;
    TASSET = _vault.getTAsset();
    IAU = IERC4626(TASSET).asset();
    REDEMPTION_CONTROLLER = _redemptionController;
  }

  modifier validateRedeem(address _userAddress, uint256 _index) {
    if (_index < redemptionInfo[_userAddress].length) {
      _;
    } else {
      revert RedemptionNotFound();
    }
  }

  /**
   * @notice Redeem tAsset
   * @param _shares amount of tAsset to redeem
   */
  function redeem(uint96 _shares) external nonReentrant whenNotPaused {
    uint128 _assets = IERC4626(TASSET).previewRedeem(_shares).toUint128();
    if (_assets < minRedeemInUnderlying) revert MinimumNotMet();

    IERC20(TASSET).safeTransferFrom(msg.sender, address(this), _shares);

    redemptionInfo[msg.sender].push(
      RedemptionInfo({
        startTime: block.timestamp.toUint64(),
        assets: _assets,
        shares: _shares,
        baseRate: _getBaseRate().toUint128()
      })
    );

    unchecked {
      redeeming[msg.sender] += _shares;
      totalRedeeming += _shares;
    }

    emit Redeemed(msg.sender, _shares, _assets);
  }

  /**
   * @notice Finalize tAsset redemption
   * @param _redeemIndex index to finalize
   */
  function finalizeRedeem(
    uint _redeemIndex
  ) external nonReentrant whenNotPaused validateRedeem(msg.sender, _redeemIndex) {
    RedemptionInfo storage _redeem = redemptionInfo[msg.sender][_redeemIndex];

    if (block.timestamp < _redeem.startTime + waitingPeriod) revert InWaitingPeriod();
    uint _assets = IERC4626(TASSET).redeem(_redeem.shares, address(this), address(this));
    redeeming[msg.sender] -= _redeem.shares;
    totalRedeeming -= _redeem.shares;

    address _underlying = VAULT.getUnderlying();

    uint _returnAmount = _getReturnAmount(_redeem.assets, _redeem.baseRate, _assets, _getBaseRate());
    uint _fee = (_returnAmount * redemptionFee) / PRECISION;
    _returnAmount = _returnAmount - _fee;

    if (_returnAmount > _redeem.assets) revert RedemptionError();

    if (IERC20(_underlying).balanceOf(address(VAULT)) < _returnAmount) revert InsufficientFundsInVault();
    IInternalAccountingUnit(IAU).burn(_returnAmount);
    REDEMPTION_CONTROLLER.redeem(_returnAmount, msg.sender);

    // reused assignment - transfer leftover asset back into 4626
    _assets = IERC20(IAU).balanceOf(address(this));

    if (_assets > 0) {
      IERC20(IAU).safeTransfer(TASSET, _assets);
    }

    emit RedeemFinalized(msg.sender, _returnAmount, _fee);

    // last because deletes are in-place
    _deleteRedeemEntry(_redeemIndex);
  }

  /**
   * @notice Set the waiting period for finalizing redeems
   * @param _newWaitingPeriod new waiting period in seconds
   */
  function setWaitingPeriod(uint32 _newWaitingPeriod) external onlyOwner {
    emit WaitingPeriodUpdated(_newWaitingPeriod, waitingPeriod);
    waitingPeriod = _newWaitingPeriod;
  }

  /**
   * @notice Set the minimum redemption size
   * @dev must be the same amount of decimals as underlying
   * @param _minRedeemInUnderlying new minimum in IERC20(underlying).decimals()
   */
  function setMinRedeem(uint96 _minRedeemInUnderlying) external onlyOwner {
    emit MinRedeemUpdated(_minRedeemInUnderlying, minRedeemInUnderlying);
    minRedeemInUnderlying = _minRedeemInUnderlying;
  }

  /**
   * @notice Set redemption fee
   * @param _newFee new redemption fee
   */
  function setRedemptionFee(uint32 _newFee) external onlyOwner {
    if (_newFee > PRECISION) revert FeeExceeded();
    emit RedemptionFeeUpdated(_newFee, redemptionFee);
    redemptionFee = _newFee;
  }

  /**
   * @notice Gets the redemption info of a user's redeem index
   * @param _user address of user
   * @param _redeemIndex user's redeem index
   */
  function getRedeemInfo(
    address _user,
    uint _redeemIndex
  ) external view validateRedeem(_user, _redeemIndex) returns (RedemptionInfo memory) {
    return redemptionInfo[_user][_redeemIndex];
  }

  /**
   * @notice Gets the total number of redemptions in progress
   * @param _user address of user
   * @return number of in progress redemptions of user
   */
  function getRedeemLength(address _user) external view returns (uint256) {
    return redemptionInfo[_user].length;
  }

  /**
   * @notice Get all pending redemptions of user
   * @dev no guarantee of chronological ordering
   * @param _user address of user
   * @return array of in progress redemptions of user
   */
  function getPendingRedeems(address _user) external view returns (RedemptionInfo[] memory) {
    return redemptionInfo[_user];
  }

  /**
   * @notice Gas efficient way to delete a element in an array
   * @dev tradeoff - no guarantee of chronological ordering
   * @param index of redeem
   */
  function _deleteRedeemEntry(uint256 index) internal {
    redemptionInfo[msg.sender][index] = redemptionInfo[msg.sender][redemptionInfo[msg.sender].length - 1];
    redemptionInfo[msg.sender].pop();
  }

  /**
   * @notice Get the amount of asset/underlying to return before fees
   * @param _b0 redeemable assets at redeem
   * @param _c0 asset rate at redeem
   * @param _bn redeemable assets at finalize
   * @param _cn asset rate at finalize
   * @return return amount in underlying
   */
  function _getReturnAmount(uint128 _b0, uint128 _c0, uint _bn, uint _cn) internal pure returns (uint) {
    uint _minC;
    uint _maxC;

    if (_c0 > _cn) {
      _minC = _cn;
      _maxC = _c0;
    } else {
      _minC = _c0;
      _maxC = _cn;
    }

    return (_minC * (_b0 > _bn ? _bn : _b0)) / _maxC;
  }

  /**
   * @notice Get base rate of asset
   */
  function _getBaseRate() private view returns (uint) {
    return IwstETH(payable(VAULT.getUnderlying())).stEthPerToken();
  }

  ///////////////////////////////////////////// Overrides /////////////////////////////////////////////

  /**
   * Inherits pause state from RedemptionController
   */
  function paused() public view override returns (bool) {
    return REDEMPTION_CONTROLLER.paused();
  }

  ////////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
    super._transferOwnership(newOwner);
  }
}
