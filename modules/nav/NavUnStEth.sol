// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import { IUnStEth } from '../../interfaces/lido/IUnStEth.sol';
import { IwstETH } from '../../interfaces/lido/IwstETH.sol';
import { IRateProviderRegistry } from '../../rate-providers/RateProviderRegistry.sol';

/**
 * @notice Module to get lido redemption NFTs' NAV
 */
contract NavUnStEth {
  address public immutable stETH;
  IUnStEth public immutable unStETH;
  IwstETH public immutable wstETH;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  error NotRequestOwner();
  error AlreadyClaimed();

  constructor(IUnStEth _unsteth, IRateProviderRegistry _rpr) {
    unStETH = _unsteth;
    RATE_PROVIDER_REGISTRY = _rpr;
    stETH = _unsteth.STETH();
    wstETH = IwstETH(payable(_unsteth.WSTETH()));
  }

  /**
   * @notice get sum of `_lidoRequestIds` NFT NAV of `_target`
   * @param _target target address
   * @param _lidoRequestIds lido request Id array
   * @return _nav nav in wstETH terms
   */
  function nav(address _target, uint[] calldata _lidoRequestIds) external view returns (uint _nav) {
    if (_lidoRequestIds.length == 0) return 0;

    IUnStEth.WithdrawalRequestStatus[] memory _status = unStETH.getWithdrawalStatus(_lidoRequestIds);

    for (uint i; i < _status.length; ++i) {
      if (_status[i].owner != _target) revert NotRequestOwner();
      if (_status[i].isClaimed) revert AlreadyClaimed();

      unchecked {
        _nav += _status[i].amountOfStETH;
      }
    }
    _nav = IwstETH(wstETH).getWstETHByStETH(_nav);
  }
}
