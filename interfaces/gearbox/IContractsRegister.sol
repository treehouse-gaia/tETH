// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://etherscan.io/address/0xA50d4E7D8946a7c90652339CDBd262c375d54D99
interface IContractsRegister {
  function getPools() external view returns (address[] memory);

  function getPoolsCount() external view returns (uint);

  function isPool(address maybePool) external view returns (bool isPool);

  function paused() external view returns (bool);
}
