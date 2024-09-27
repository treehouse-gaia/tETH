// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../rate-providers/IRateProvider.sol';

contract MockRateProvider is IRateProvider {
  uint rate;

  function setRate(uint _rate) external {
    rate = _rate;
  }

  function getRate() external view returns (uint) {
    return rate;
  }
}
