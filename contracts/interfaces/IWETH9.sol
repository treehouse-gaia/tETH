// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://etherscan.io/token/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
interface IWETH9 {
  function deposit() external payable;

  function withdraw(uint256 wad) external;
}
