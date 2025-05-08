// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import { IRateProviderRegistry } from '../../rate-providers/RateProviderRegistry.sol';

interface IwstETH {
  function stETH() external view returns (address);

  function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

interface INavErc20WithDebt {
  function nav(
    address _target,
    address[] memory _assetTokens,
    address[] memory _debtTokens
  ) external view returns (uint _nav);
}

/**
 * @notice Module to get NAV of list of ERC20 asset tokens, and debt tokens
 * @dev invariant: debt tokens' value MUST be <= asset tokens' value
 */
contract NavErc20WithDebt is INavErc20WithDebt {
  error InvariantViolation();

  IwstETH public immutable wstETH;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  constructor(IwstETH _wsteth, IRateProviderRegistry _rpr) {
    wstETH = _wsteth;
    RATE_PROVIDER_REGISTRY = _rpr;
  }

  /**
   * get sum of `_assetTokens` + native token NAV of `_target` - sum of `_debtTokens`
   * @param _target target address
   * @param _assetTokens asset tokens
   * @param _debtTokens debt tokens
   * @return _nav NAV in wsteth
   */
  function nav(
    address _target,
    address[] memory _assetTokens,
    address[] memory _debtTokens
  ) external view returns (uint _nav) {
    _nav += _target.balance;

    uint wip;
    uint wstETHBalance;
    for (uint i; i < _assetTokens.length; ++i) {
      wip = IERC20(_assetTokens[i]).balanceOf(_target);

      if (wip > 0) {
        unchecked {
          if (_assetTokens[i] == address(wstETH)) {
            wstETHBalance = wip;
          } else if (_assetTokens[i] == address(wstETH.stETH())) {
            _nav += wip;
          } else {
            _nav += (RATE_PROVIDER_REGISTRY.getRateInEth(_assetTokens[i]) * wip) / 1e18;
          }
        }
      }
    }

    for (uint i; i < _debtTokens.length; ++i) {
      wip = IERC20(_debtTokens[i]).balanceOf(_target);

      if (wip > 0) {
        uint _debtInEth = (RATE_PROVIDER_REGISTRY.getRateInEth(_debtTokens[i]) * wip) / 1e18;

        if (_debtInEth > _nav) {
          revert InvariantViolation();
        } else {
          _nav -= _debtInEth;
        }
      }
    }

    _nav = wstETH.getWstETHByStETH(_nav) + wstETHBalance;
  }
}
