// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';

import { ITreehouseAccounting } from '../TreehouseAccounting.sol';
import { INavLens } from './NavLens.sol';
import { INavRegistry } from '../NavRegistry.sol';

/**
 * @notice Entry point for protocol PNL calculation
 */
contract PnlAccounting is Ownable2Step, Pausable {
  uint constant PRECISION = 1e4;

  ITreehouseAccounting public immutable TREEHOUSE_ACCOUNTING;
  INavLens public immutable NAV_LENS;

  error Unauthorized();
  error DeviationExceeded();
  error StillInWaitingPeriod();
  error InvalidCooldown();

  event ExecutorUpdated(address indexed latest, address indexed old);
  event PauserUpdated(address indexed latest, address indexed old);
  event CooldownUpdated(uint16 latest, uint16 old);
  event DeviationUpdated(uint16 latest, uint16 old);

  address public executor;
  uint16 public deviation = 250; // 1e6 base. 250 == 0.025%
  uint16 public cooldown = 3600; // in seconds
  uint64 public nextWindow;
  address public pauser;

  constructor(address _owner, INavLens _navLens, ITreehouseAccounting _accounting) Ownable(_owner) {
    NAV_LENS = _navLens;
    TREEHOUSE_ACCOUNTING = _accounting;
  }

  modifier onlyOwnerOrExecutor() {
    if (msg.sender != executor && msg.sender != owner()) revert Unauthorized();
    _;
  }

  /**
   * @notice mark to market protocol NAV
   */
  function doAccounting(
    INavRegistry.ModuleParams[][] calldata dynamicModuleParams
  ) external whenNotPaused onlyOwnerOrExecutor {
    unchecked {
      if (block.timestamp < nextWindow) revert StillInWaitingPeriod();
      nextWindow = (uint64(block.timestamp) + cooldown);

      uint _lastNav = NAV_LENS.lastRecordedProtocolNav();
      uint _currentNav = NAV_LENS.currentProtocolNav(dynamicModuleParams);

      bool _isPnlPositive = _currentNav > _lastNav;
      uint _netPnl = _isPnlPositive ? _currentNav - _lastNav : _lastNav - _currentNav;

      if (_netPnl > maxPnl()) revert DeviationExceeded();

      if (_isPnlPositive) {
        uint _fee = (_netPnl * TREEHOUSE_ACCOUNTING.fee()) / PRECISION;
        _netPnl -= _fee;
        TREEHOUSE_ACCOUNTING.mark(ITreehouseAccounting.MarkType.MINT, _netPnl, _fee);
      } else {
        TREEHOUSE_ACCOUNTING.mark(ITreehouseAccounting.MarkType.BURN, _netPnl, 0);
      }
    }
  }

  /**
   * @notice max PNL threshold per accounting window
   * in terms of the underlying asset
   */
  function maxPnl() public view returns (uint) {
    return (deviation * NAV_LENS.lastRecordedProtocolNav()) / PRECISION;
  }

  /**
   * @notice Set the pause state of the contract
   * @dev owner or pauser
   * @param _paused is contract paused
   */
  function setPause(bool _paused) external {
    if (msg.sender != owner() && msg.sender != pauser) revert Unauthorized();

    if (_paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /**
   * @notice Set a dedicated pauser for the contract
   * @param _pauser pauser address
   */
  function setPauser(address _pauser) external onlyOwner {
    emit PauserUpdated(pauser, _pauser);
    pauser = _pauser;
  }

  /**
   * @notice Set a cooldown for accounting
   * @param _newCooldownInSeconds new cooldown in seconds
   */
  function setCooldownSeconds(uint16 _newCooldownInSeconds) external onlyOwner {
    if (_newCooldownInSeconds < 60 || _newCooldownInSeconds > 2 days) revert InvalidCooldown();
    emit CooldownUpdated(_newCooldownInSeconds, cooldown);
    cooldown = _newCooldownInSeconds;
  }

  /**
   * @notice Update executor of accounting
   * @param _newExecutor new executor
   */
  function updateExecutor(address _newExecutor) external onlyOwner {
    emit ExecutorUpdated(_newExecutor, executor);
    executor = _newExecutor;
  }

  /**
   * @notice Deviation of profit in 1e6. E.g. 200 = +/- 0.02%
   * @param _newDeviation new deviation
   */
  function setDeviation(uint16 _newDeviation) external onlyOwner {
    if (_newDeviation > PRECISION) revert DeviationExceeded();
    emit DeviationUpdated(_newDeviation, deviation);
    deviation = _newDeviation;
  }
}
