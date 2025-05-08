// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import { IPoolV3 } from '../../interfaces/aaveV3/IPoolV3.sol';
import { IwstETH } from '../../interfaces/lido/IwstETH.sol';
import { IRateProviderRegistry } from '../../rate-providers/RateProviderRegistry.sol';

/**
 * @notice Module to get NAV of aave v3 position
 */
contract NavAaveV3 {
  uint constant PRECISION = 1e18;

  IwstETH public immutable wstETH;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  constructor(IwstETH _wsteth, IRateProviderRegistry _rpr) {
    wstETH = _wsteth;
    RATE_PROVIDER_REGISTRY = _rpr;
  }

  /**
   * @notice get Aave V3 net position NAV of `_target`
   * @param _target target address
   * @param _lendingPool V3 like lending pool instance
   * @return _nav nav in wstETH terms
   */
  function nav(address _target, address _lendingPool) external view returns (uint _nav) {
    (uint totalCollateralBase, uint totalDebtBase, , , , ) = IPoolV3(_lendingPool).getUserAccountData(_target);

    // 1e8 base
    uint navInBase = (totalCollateralBase - totalDebtBase);

    unchecked {
      // nav in eth
      _nav = (navInBase * 1e10 * PRECISION) / RATE_PROVIDER_REGISTRY.getEthInUsd();

      _nav = IwstETH(wstETH).getWstETHByStETH(_nav);
    }
  }
}
