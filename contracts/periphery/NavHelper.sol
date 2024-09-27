// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';

import { IRateProviderRegistry } from '../rate-providers/RateProviderRegistry.sol';
import { IPoolV3 } from '../interfaces/aaveV3/IPoolV3.sol';
import { IUnStEth } from '../interfaces/lido/IUnStEth.sol';
import { IwstETH } from '../interfaces/lido/IwstETH.sol';
import { IVault } from '../Vault.sol';

interface INavHelper {
  function getProtocolIau() external view returns (uint _navInEth);

  function getVaultNav() external view returns (uint _navInEth);

  function getVault() external view returns (address);

  function getLidoRedemptionsNav(
    uint[] calldata _lidoRequestIds,
    address _owner
  ) external view returns (uint _navInEth);

  function getAaveV3Nav(address _address) external view returns (uint _navInEth);

  function getTokensNav(address[] memory _tokens, address _target) external view returns (uint _navInEth);

  function getProtocolIauInUsd() external view returns (uint _navInUsd);
}

/**
 * @notice Helper functions to calculate protocol NAV
 */
contract NavHelper is INavHelper {
  uint constant PRECISION = 1e18;

  address public immutable stETH;
  IUnStEth public immutable unStETH;
  IERC20 public immutable IAU;
  address public immutable VAULT;
  IPoolV3 public immutable AAVE_V3_LENDING_POOL;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  error NotRequestOwner();
  error AlreadyClaimed();

  constructor(
    address _steth,
    IUnStEth _unsteth,
    IPoolV3 _aaveV3LendingPool,
    IRateProviderRegistry _rpr,
    IERC20 _iau,
    address _vault
  ) {
    stETH = _steth;
    unStETH = _unsteth;
    AAVE_V3_LENDING_POOL = _aaveV3LendingPool;
    RATE_PROVIDER_REGISTRY = _rpr;
    IAU = _iau;
    VAULT = _vault;
  }

  /**
   * @notice get protocol NAV in USD terms
   * @return _navInUsd NAV in USD terms
   */
  function getProtocolIauInUsd() external view returns (uint _navInUsd) {
    unchecked {
      _navInUsd = (IAU.totalSupply() * RATE_PROVIDER_REGISTRY.getEthInUsd()) / 1e18;
    }
  }

  /**
   * @notice get protocol NAV in wstETH terms
   * @return _navInWstEth NAV in wstETH terms
   */
  function getProtocolIau() external view returns (uint _navInWstEth) {
    _navInWstEth = IAU.totalSupply();
  }

  /**
   * @notice get vault NAV in wstETH terms
   * @return _navInWstEth NAV in wstETH terms
   */
  function getVaultNav() external view returns (uint _navInWstEth) {
    _navInWstEth = getTokensNav(IVault(VAULT).getAllowableAssets(), VAULT);
  }

  /**
   * @notice get vault address
   * @return vault address
   */
  function getVault() external view returns (address) {
    return VAULT;
  }

  /**
   * @notice get sum of `_tokens` NAV of `_target` in eth terms
   * @param _tokens token array to price
   * @param _target address to get price of
   * @return _navInWstEth NAV in wstETH terms
   */
  function getTokensNav(address[] memory _tokens, address _target) public view returns (uint _navInWstEth) {
    _navInWstEth += _target.balance;

    uint wip;
    for (uint i; i < _tokens.length; ) {
      wip = IERC20(_tokens[i]).balanceOf(_target);

      if (wip > 0) {
        _navInWstEth += _getAssetAmountInEth(_tokens[i], wip);
      }

      unchecked {
        ++i;
      }
    }

    _navInWstEth = IwstETH(payable(unStETH.WSTETH())).getWstETHByStETH(_navInWstEth);
  }

  /**
   * @notice get NAV of redemption requests that haven't been claimed
   * @param _lidoRequestIds request ids
   * @param _owner address of owner
   * @return _navInWstEth NAV in wstETH
   */
  function getLidoRedemptionsNav(
    uint[] calldata _lidoRequestIds,
    address _owner
  ) external view returns (uint _navInWstEth) {
    IUnStEth.WithdrawalRequestStatus[] memory _status = unStETH.getWithdrawalStatus(_lidoRequestIds);

    for (uint i; i < _status.length; ) {
      if (_status[i].owner != _owner) revert NotRequestOwner();
      if (_status[i].isClaimed) revert AlreadyClaimed();

      unchecked {
        _navInWstEth += _status[i].amountOfStETH;
        ++i;
      }
    }

    _navInWstEth = IwstETH(payable(unStETH.WSTETH())).getWstETHByStETH(_getAssetAmountInEth(stETH, _navInWstEth));
  }

  /**
   * @notice get aave v3 net position in eth terms
   * @param _address adress to get price of
   * @return _navInWstEth NAV in wstETH
   */
  function getAaveV3Nav(address _address) external view returns (uint _navInWstEth) {
    (uint totalCollateralBase, uint totalDebtBase, , , , ) = AAVE_V3_LENDING_POOL.getUserAccountData(_address);

    // 1e8 base
    uint navInBase = (totalCollateralBase - totalDebtBase);

    unchecked {
      _navInWstEth = IwstETH(payable(unStETH.WSTETH())).getWstETHByStETH(
        (navInBase * 1e10 * PRECISION) / RATE_PROVIDER_REGISTRY.getEthInUsd()
      );
    }
  }

  function _getAssetAmountInEth(address _asset, uint _amount) private view returns (uint _amountInEth) {
    _amountInEth = ((RATE_PROVIDER_REGISTRY.getRateInEth(_asset) * _amount) / 10 ** IERC20Metadata(_asset).decimals());
  }
}
