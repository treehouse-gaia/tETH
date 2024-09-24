// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract MockVault {
  bool public allowable = false;
  address public immutable underlying;
  address public immutable tasset;

  constructor(address _underlying, address _tasset) {
    underlying = _underlying;
    tasset = _tasset;
  }

  function getUnderlying() external view returns (address) {
    return underlying;
  }

  function getTAsset() external view returns (address) {
    return tasset;
  }

  function isAllowableAsset(address) external view returns (bool) {
    return allowable;
  }

  function setAllAssetsAllowable(bool _allowable) external {
    allowable = _allowable;
  }

  function setRedemption(address _contract) external {
    IERC20(underlying).approve(_contract, type(uint).max);
  }
}
