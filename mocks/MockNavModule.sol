// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

contract MockNavModule {
  function nav(address, uint _number) external pure returns (uint _nav) {
    _nav = _number;
  }
}
