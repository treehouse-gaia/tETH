// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://etherscan.io/address/0xff94993fa7ea27efc943645f95adb36c1b81244b
interface IPoolV3 {
  function deposit(uint256 assets, address receiver) external returns (uint256 shares);

  function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

  function asset() external view returns (address);

  function availableLiquidity() external view returns (uint);
}
