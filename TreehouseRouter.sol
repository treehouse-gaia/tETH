// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';

import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';
import { IWETH9 } from './interfaces/IWETH9.sol';
import { IVault } from './Vault.sol';
import { IwstETH } from './interfaces/lido/IwstETH.sol';
import { IstETH } from './interfaces/lido/IstETH.sol';
import './libs/Rescuable.sol';

interface ITreehouseRouter {
  error DepositCapExceeded();
  error NotAllowableAsset();
  error NoSharesMinted();
  error ConversionToUnderlyingFailed();
  error InvalidSender();

  event Deposited(address _asset, uint _amountInUnderlying, uint _shares);
  event DepositCapUpdated(uint _newDepositCap, uint _oldDepositCap);

  function deposit(address _asset, uint256 _amount) external;

  function depositETH() external payable;
}

/**
 * @notice TreehouseRouter is the entrypoint for deposits into Treehouse Protocol
 */
contract TreehouseRouter is ITreehouseRouter, Ownable2Step, ReentrancyGuard, Pausable, Rescuable {
  using SafeERC20 for IERC20;

  address public immutable WETH;
  address public immutable stETH;
  address public immutable wstETH;
  address public immutable IAU;
  IERC4626 public immutable TASSET;
  IVault public immutable VAULT;

  uint public depositCapInEth;

  constructor(
    address _creator,
    address _weth,
    address _stEth,
    address _wstEth,
    IVault _vault,
    uint _depositCapInEth
  ) Ownable(_creator) {
    WETH = _weth;
    stETH = _stEth;
    wstETH = _wstEth;

    VAULT = _vault;
    TASSET = IERC4626(_vault.getTAsset());
    IAU = TASSET.asset();

    depositCapInEth = _depositCapInEth;

    IERC20(IAU).approve(address(TASSET), type(uint).max);
    IERC20(stETH).approve(wstETH, type(uint).max);
  }

  receive() external payable {
    if (msg.sender != WETH) revert InvalidSender();
  }

  /**
   * @notice for ERC20 deposits
   * @param _asset asset to deposit
   * @param _amount amount to deposit
   * @dev must be a Vault.allowableAsset; needs approval from user
   */
  function deposit(address _asset, uint256 _amount) public nonReentrant whenNotPaused {
    if (VAULT.isAllowableAsset(_asset) == false) revert NotAllowableAsset();
    uint _valueInUnderlying;

    if (_asset == VAULT.getUnderlying()) {
      IERC20(_asset).safeTransferFrom(msg.sender, address(VAULT), _amount);
      _valueInUnderlying = _amount;
    } else {
      IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
      _valueInUnderlying = _convertToUnderlying(_asset, _amount);
      IERC20(VAULT.getUnderlying()).safeTransfer(address(VAULT), _valueInUnderlying);
    }

    uint _shares = _mintAndStake(_valueInUnderlying, msg.sender);
    _checkEthCap();
    if (_shares == 0) revert NoSharesMinted();
    emit Deposited(_asset, _valueInUnderlying, _shares);
  }

  /**
   * @notice for native ETH deposits into the protocol
   */
  function depositETH() public payable nonReentrant whenNotPaused {
    uint _valueInUnderlying = _ethToWsteth(msg.value);
    IERC20(VAULT.getUnderlying()).safeTransfer(address(VAULT), _valueInUnderlying);

    uint _shares = _mintAndStake(_valueInUnderlying, msg.sender);
    _checkEthCap();
    if (_shares == 0) revert NoSharesMinted();
    emit Deposited(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, _valueInUnderlying, _shares);
  }

  /**
   * @notice sets deposit cap of protocol
   * @param _newCap new deposit cap
   */
  function setDepositCap(uint _newCap) external onlyOwner {
    emit DepositCapUpdated(_newCap, depositCapInEth);
    depositCapInEth = _newCap;
  }

  /**
   * @notice Set the pause state of the contract
   * @param _paused is contract paused
   */
  function setPause(bool _paused) external onlyOwner {
    if (_paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @dev atomically mint + stake iau into tAsset
  function _mintAndStake(uint _iauAmount, address _receiver) internal returns (uint) {
    IInternalAccountingUnit(IAU).mintTo(address(this), _iauAmount);
    return TASSET.deposit(_iauAmount, _receiver);
  }

  function _checkEthCap() internal view {
    unchecked {
      if (_getUnderlyingInEth(IERC20(IAU).totalSupply()) > depositCapInEth) revert DepositCapExceeded();
    }
  }

  function _getUnderlyingInEth(uint _underlyingAmount) private view returns (uint) {
    return IwstETH(payable(wstETH)).getStETHByWstETH(_underlyingAmount);
  }

  function _convertToUnderlying(address _asset, uint _amount) private returns (uint) {
    if (_asset == WETH) {
      return _wethToWsteth(_amount);
    } else if (_asset == stETH) {
      return _stethToWsteth(_amount);
    }

    revert ConversionToUnderlyingFailed();
  }

  function _wethToWsteth(uint amount) private returns (uint) {
    IWETH9(WETH).withdraw(amount);
    return _ethToWsteth(amount);
  }

  function _ethToWsteth(uint amount) private returns (uint) {
    return _stethToWsteth(IstETH(stETH).getPooledEthByShares((IstETH(stETH).submit{ value: amount }(address(0)))));
  }

  function _stethToWsteth(uint stethAmount) private returns (uint) {
    return IwstETH(payable(wstETH)).wrap(stethAmount);
  }

  ////////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
    super._transferOwnership(newOwner);
  }
}
