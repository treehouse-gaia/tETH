// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import { IRateProviderRegistry } from '../../rate-providers/RateProviderRegistry.sol';

interface IwstETH {
  function stETH() external view returns (address);

  function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

interface INavErc20 {
  function nav(address _target, address[] memory _tokens) external view returns (uint _nav);
}

/**
 * @notice Module to get NAV of list of ERC20s
 */
contract NavErc20 is INavErc20 {
  IwstETH public immutable wstETH;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  constructor(IwstETH _wsteth, IRateProviderRegistry _rpr) {
    wstETH = _wsteth;
    RATE_PROVIDER_REGISTRY = _rpr;
  }

  /**
   * @notice get sum of `_tokens` + native token NAV of `_target`
   * @param _target address to target
   * @param _tokens token array to price
   * @return _nav NAV in wstETH terms
   */
  function nav(address _target, address[] memory _tokens) external view returns (uint _nav) {
    _nav += _target.balance;

    uint wip;
    uint wstETHBalance;
    for (uint i; i < _tokens.length; ++i) {
      wip = IERC20(_tokens[i]).balanceOf(_target);

      if (wip > 0) {
        unchecked {
          if (_tokens[i] == address(wstETH)) {
            wstETHBalance = wip;
          } else if (_tokens[i] == address(wstETH.stETH())) {
            _nav += wip;
          } else {
            _nav += (RATE_PROVIDER_REGISTRY.getRateInEth(_tokens[i]) * wip) / 1e18;
          }
        }
      }
    }

    _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
  }
}
