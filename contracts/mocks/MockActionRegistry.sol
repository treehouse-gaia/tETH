// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

contract MockActionRegistry {
  address _addr;

  function getAddr(bytes4) external view returns (address) {
    return _addr;
  }

  function setAddr(address _newAddr) external {
    _addr = _newAddr;
  }
}
