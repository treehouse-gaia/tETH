// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';

import { INavHelper } from './NavHelper.sol';
import { ITreehouseAccounting } from '../TreehouseAccounting.sol';

interface IHurdleRate {
  function getHurdleRate() external view returns (uint256);
}

/**
 * @notice Entry point for protocol PNL calculation
 */
contract PnlAccountingHelper is Ownable2Step {
  uint constant PRECISION = 1e4;

  address public immutable WETH;
  address public immutable wstETH;
  INavHelper public immutable NAV_HELPER;
  ITreehouseAccounting public immutable TREEHOUSE_ACCOUNTING;
  address public immutable STRATEGY;

  error Unauthorized();
  error DeviationExceeded();

  event ExecutorUpdated(address indexed _new, address indexed _old);
  event DeviationUpdated(uint16 _new, uint16 _old);

  address public executor;
  uint16 public deviation; // in bips

  constructor(
    address _owner,
    address _weth,
    address _wstEth,
    INavHelper _navHelper,
    address _strategy,
    ITreehouseAccounting _accounting,
    uint16 _deviation
  ) Ownable(_owner) {
    WETH = _weth;
    wstETH = _wstEth;
    NAV_HELPER = _navHelper;
    TREEHOUSE_ACCOUNTING = _accounting;
    STRATEGY = _strategy;
    deviation = _deviation;
  }

  modifier onlyOwnerOrExecutor() {
    if (msg.sender != executor && msg.sender != owner()) revert Unauthorized();
    _;
  }

  /**
   * @notice function to mark to market protocol NAV
   * @param _lidoRequestIds list of lido request ids
   */
  function doAccounting(uint[] memory _lidoRequestIds) external onlyOwnerOrExecutor {
    (bool _isProfit, uint _pnlLessFee, uint _fee) = getPnl(_lidoRequestIds);
    if (_pnlLessFee > maxPnl()) revert DeviationExceeded();

    if (_isProfit) {
      TREEHOUSE_ACCOUNTING.mark(ITreehouseAccounting.MarkType.MINT, _pnlLessFee, _fee);
    } else {
      TREEHOUSE_ACCOUNTING.mark(ITreehouseAccounting.MarkType.BURN, _pnlLessFee, 0);
    }
  }

  /**
   * @notice max PNL possible according to last NAV and deviation.
   */
  function maxPnl() public view returns (uint) {
    return (deviation * NAV_HELPER.getProtocolIau()) / PRECISION;
  }

  /**
   * @notice returns pnl of protocol
   * @param _lidoRequestIds unclaimed lido request ids
   * @return _isProfit true if in profit, false if in loss
   * @return _pnl profit/loss less fee, fee = 0 if loss
   * @return _fee protcol fee levied on excess profits above hurdle
   */
  function getPnl(uint[] memory _lidoRequestIds) public view returns (bool _isProfit, uint _pnl, uint _fee) {
    uint _lastNav = NAV_HELPER.getProtocolIau();
    uint _currentNav = NAV_HELPER.getVaultNav() + getNavOfStrategy(_lidoRequestIds);

    if (_currentNav > _lastNav) {
      _isProfit = true;
      _pnl = _currentNav - _lastNav;

      _fee = (_pnl * TREEHOUSE_ACCOUNTING.fee()) / PRECISION;
      _pnl -= _fee;
    } else {
      _isProfit = false;
      _pnl = _lastNav - _currentNav;
    }
  }

  /**
   * @notice get strategy NAV in eth
   * @return _navInEth strategy NAV in eth
   */
  function getNavOfStrategy(uint[] memory _lidoRequestIds) public view returns (uint _navInEth) {
    address[] memory tokens = new address[](2);
    tokens[0] = WETH;
    tokens[1] = wstETH;

    _navInEth = NAV_HELPER.getTokensNav(tokens, STRATEGY);
    _navInEth += NAV_HELPER.getAaveV3Nav(STRATEGY);
    _navInEth += NAV_HELPER.getLidoRedemptionsNav(_lidoRequestIds, STRATEGY);
  }

  /**
   * @notice update executor of accounting
   * @param _newExecutor new executor
   */
  function updateExecutor(address _newExecutor) external onlyOwner {
    emit ExecutorUpdated(_newExecutor, executor);
    executor = _newExecutor;
  }

  /**
   * @notice Deviation of profit in bips. E.g. 200 = +/- 2%
   * @param _newDeviation new deviation
   */
  function setDeviation(uint16 _newDeviation) external onlyOwner {
    if (deviation > PRECISION) revert DeviationExceeded();
    emit DeviationUpdated(_newDeviation, deviation);
    deviation = _newDeviation;
  }
}
