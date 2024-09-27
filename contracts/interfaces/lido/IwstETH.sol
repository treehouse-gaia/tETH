// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://docs.lido.fi/contracts/wsteth
/// @dev https://etherscan.io/token/0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0
interface IwstETH {
  /**
   * Get amount of stETH for a given amount of wstETH
   * @param _wstETHAmount amount of wstETH
   * @return Amount of stETH for a given wstETH amount
   */
  function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);

  /**
   * Get amount of wstETH for a given amount of stETH
   * @param _stETHAmount amount of stETH
   * @return Amount of wstETH for a given stETH amount
   */
  function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);

  /**
   * @return Returns the amount of stETH tokens corresponding to one wstETH
   */
  function stEthPerToken() external view returns (uint256);

  /**
   * Exchanges stETH to wstETH
   * @param _stETHAmount amount of stETH to wrap in exchange for wstETH
   * @return Amount of wstETH user receives after wrap
   */
  function wrap(uint256 _stETHAmount) external returns (uint256);

  /**
   * Exchanges wstETH to stETH
   * @param _wstETHAmount amount of wstETH to unwrap in exchange for stETH
   * @return Amount of stETH user receives after unwrapping
   */
  function unwrap(uint256 _wstETHAmount) external returns (uint256);

  /**
   * Shortcut to stake ETH and auto-wrap returned stETH
   */
  receive() external payable;
}
