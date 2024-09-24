// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

contract MockStrategyStorage {
  bool stratActive;
  bool assetWhitelisted;
  bool actionWhitelisted;
  address stratAddress;
  address public strategyExecutor;

  function set(bool _isStratActive, bool _isAssetWhitelisted) external {
    stratActive = _isStratActive;
    assetWhitelisted = _isAssetWhitelisted;
  }

  function setStrategyExecutor(address _new) external {
    strategyExecutor = _new;
  }

  function isActiveStrategy(address) external view returns (bool) {
    return stratActive;
  }

  function isAssetWhitelisted(address, address) external view returns (bool) {
    return assetWhitelisted;
  }

  function setActionWhitelisted(bool isWhitelisted) external {
    actionWhitelisted = isWhitelisted;
  }

  function isActionWhitelisted(address, bytes4) external view returns (bool) {
    return actionWhitelisted;
  }

  function setStrategyAddress(address _addr) external {
    stratAddress = _addr;
  }

  function getStrategyAddress(uint) external view returns (address) {
    return stratAddress;
  }
}
