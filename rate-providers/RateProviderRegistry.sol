// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IRateProvider } from './IRateProvider.sol';

interface IRateProviderRegistry {
  error RateProviderNotFound();
  error InvalidAddress();

  event RateProviderUpdated(address indexed _asset, address indexed _rateProvider, address _oldProvider);

  function getRateInEth(address _asset) external view returns (uint _rateInEth);

  function checkHasRateProvider(address _asset) external view;

  function getEthInUsd() external view returns (uint);
}

/**
 * @notice RateProviderRegistry stores the asset and corresponding rate providers used by the protocol
 */
contract RateProviderRegistry is IRateProviderRegistry, Ownable2Step {
  address public immutable WETH;
  IRateProvider public immutable ETH_USD_ORACLE;
  mapping(address => address) private rateProviders; //asset => rateProvider

  constructor(address _creator, address _weth, IRateProvider _ethUsd) Ownable(_creator) {
    WETH = _weth;
    ETH_USD_ORACLE = _ethUsd;
  }

  /**
   * @notice Returns the rate of an asset in eth terms
   * @param _asset token address, must be the base currency (not quote)
   * @return _rateInEth the exchange rate in 1e18
   */
  function getRateInEth(address _asset) external view returns (uint _rateInEth) {
    if (_asset == WETH) return 1e18;

    if (rateProviders[_asset] == address(0)) revert RateProviderNotFound();
    _rateInEth = IRateProvider(rateProviders[_asset]).getRate();
  }

  /**
   * @notice Returns the rate eth in usd terms
   * @return the exchange rate in 1e18
   */
  function getEthInUsd() external view returns (uint) {
    return ETH_USD_ORACLE.getRate();
  }

  /**
   * @notice reverts if a given asset has no rate provider
   * @param _asset provided asset
   */
  function checkHasRateProvider(address _asset) external view {
    if (_asset == WETH) return;
    if (rateProviders[_asset] == address(0)) revert RateProviderNotFound();
  }

  /**
   * @notice Updates the registry with the asset and corresponding rate provider
   * @param _asset provided asset
   * @param _rateProvider provided IRateProvider
   * @dev onlyOwner
   */
  function update(address _asset, address _rateProvider) external onlyOwner {
    if (_asset == address(0) || _rateProvider == address(0)) revert InvalidAddress();

    emit RateProviderUpdated(_asset, _rateProvider, rateProviders[_asset]);
    rateProviders[_asset] = _rateProvider;
  }
}
