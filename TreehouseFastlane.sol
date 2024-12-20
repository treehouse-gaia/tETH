// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';

import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';
import { IVault } from './Vault.sol';
import { IFastlaneFee } from './periphery/FastlaneFee.sol';
import { IRedemptionController } from './RedemptionController.sol';
import './libs/Rescuable.sol';

interface ITreehouseFastlane {
  error MinimumNotMet();
  error InsufficientFundsInVault();
  error ZeroAddress();

  event Redeemed(address indexed user, uint shares, uint assets, uint fee);
  event MinRedeemUpdated(uint128 latest, uint128 old);
  event FeeContractUpdated(IFastlaneFee latest, IFastlaneFee old);
}

interface ITreehouseRedemption {
  function totalRedeeming() external view returns (uint96);
}

/**
 * @notice Facilitate atomic redemption of tAssets
 */
contract TreehouseFastlane is ITreehouseFastlane, Ownable2Step, ReentrancyGuard, Pausable, Rescuable {
  using SafeERC20 for IERC20;

  address public immutable IAU;
  address public immutable TASSET;
  IRedemptionController public immutable REDEMPTION_CONTROLLER;
  address public immutable REDEMPTION_CONTRACT;
  IERC20 public immutable UNDERLYING;
  IVault public immutable VAULT;

  address public treasury;
  IFastlaneFee public feeContract;
  uint96 public minRedeemInUnderlying;

  constructor(
    address _creator,
    IVault _vault,
    address _treasury,
    IRedemptionController _redemptionController,
    address _redemptionContract,
    IFastlaneFee _feeContract
  ) Ownable(_creator) {
    VAULT = _vault;
    TASSET = _vault.getTAsset();
    IAU = IERC4626(TASSET).asset();
    REDEMPTION_CONTROLLER = _redemptionController;
    REDEMPTION_CONTRACT = _redemptionContract;
    UNDERLYING = IERC20(_vault.getUnderlying());
    treasury = _treasury;
    feeContract = _feeContract;
  }

  /**
   * @notice Atomically redeem tAsset
   * @param _shares amount of tAsset to redeem
   */
  function redeemAndFinalize(uint96 _shares) external nonReentrant whenNotPaused {
    uint _assets = IERC4626(TASSET).previewRedeem(_shares);
    if (_assets < minRedeemInUnderlying) revert MinimumNotMet();
    if (getRedeemableAmount() < _assets) revert InsufficientFundsInVault();

    IERC20(TASSET).safeTransferFrom(msg.sender, address(this), _shares);
    _assets = IERC4626(TASSET).redeem(_shares, address(this), address(this));
    uint _fee = feeContract.applyFee(_assets);

    IInternalAccountingUnit(IAU).burn(_assets);

    REDEMPTION_CONTROLLER.redeem(_assets - _fee, msg.sender);
    REDEMPTION_CONTROLLER.redeem(_fee, treasury);

    emit Redeemed(msg.sender, _shares, _assets, _fee);
  }

  /**
   * @notice Set the minumum redemption size
   * @param _newMinRedeemInUnderlying new minimum in 1e18
   */
  function setMinRedeem(uint96 _newMinRedeemInUnderlying) external onlyOwner {
    emit MinRedeemUpdated(_newMinRedeemInUnderlying, minRedeemInUnderlying);
    minRedeemInUnderlying = _newMinRedeemInUnderlying;
  }

  /**
   * @notice Set fee contract
   * @param _newContract new fee contract
   */
  function setFeeContract(IFastlaneFee _newContract) external onlyOwner {
    if (_newContract == IFastlaneFee(address(0))) revert ZeroAddress();
    emit FeeContractUpdated(_newContract, feeContract);
    feeContract = _newContract;
  }

  /**
   * @notice Get amount of underlying that can be atomically redeemed from vault
   * @return _totalRedeemable amount that can be atomically redeemed
   */
  function getRedeemableAmount() public view returns (uint _totalRedeemable) {
    uint _underlyingInVault = IERC20(UNDERLYING).balanceOf(address(VAULT));
    uint _approximateEarmark = IERC4626(TASSET).convertToAssets(
      ITreehouseRedemption(REDEMPTION_CONTRACT).totalRedeeming()
    );

    _totalRedeemable = _approximateEarmark > _underlyingInVault ? 0 : _underlyingInVault - _approximateEarmark;
  }

  /**
   * @notice Get atomic redemption fee
   * @return _feeInBips redemption fee in bips
   */
  function redemptionFee() external view returns (uint _feeInBips) {
    _feeInBips = IFastlaneFee(feeContract).fee();
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
