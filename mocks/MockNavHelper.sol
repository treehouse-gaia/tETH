// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import { INavHelper } from '../periphery/NavHelper.sol';

contract MockNavHelper is INavHelper {
  uint protocolIau;
  uint vaultNav;
  address vault;
  uint lidoRedemptionNav;
  uint aaveV3Nav;
  uint tokensNav;
  uint protocolIauUsd;

  function setProtocolIau(uint _param) external {
    protocolIau = _param;
  }

  function setVaultNav(uint _param) external {
    vaultNav = _param;
  }

  function setVault(address _param) external {
    vault = _param;
  }

  function setLidoRedemptionNav(uint _param) external {
    lidoRedemptionNav = _param;
  }

  function setAaveV3Nav(uint _param) external {
    aaveV3Nav = _param;
  }

  function setTokensNav(uint _param) external {
    tokensNav = _param;
  }

  function setProtocolIauUsd(uint _param) external {
    protocolIauUsd = _param;
  }

  function getProtocolIau() external view returns (uint _navInEth) {
    _navInEth = protocolIau;
  }

  function getVaultNav() external view returns (uint _navInEth) {
    _navInEth = vaultNav;
  }

  function getVault() external view returns (address) {}

  function getLidoRedemptionsNav(uint[] calldata, address) external view returns (uint _navInEth) {
    _navInEth = lidoRedemptionNav;
  }

  function getAaveV3Nav(address) external view returns (uint _navInEth) {
    _navInEth = aaveV3Nav;
  }

  function getTokensNav(address[] memory, address) external view returns (uint _navInEth) {
    _navInEth = tokensNav;
  }

  function getProtocolIauInUsd() external view returns (uint _navInUsd) {
    _navInUsd = protocolIauUsd;
  }
}
