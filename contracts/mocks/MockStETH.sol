// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import { IstETH } from '../interfaces/lido/IstETH.sol';

contract MockStETH is ERC20Permit, IstETH {
  uint256 private _totalPooledEther;
  uint256 private _totalShares;

  constructor(uint pooledEther, uint totalShares) ERC20('stETH', 'stETH') ERC20Permit('stETH') {
    _totalPooledEther = pooledEther;
    _totalShares = totalShares;
  }

  receive() external payable {}

  function submit(address) external payable returns (uint256) {
    _mint(msg.sender, msg.value);
    return msg.value;
  }

  function getPooledEthByShares(uint sharesAmount) external view returns (uint) {
    return (sharesAmount * _totalPooledEther) / _totalShares;
  }

  function getTotalPooledEther() external view returns (uint256) {
    return _totalPooledEther;
  }

  function getTotalShares() external view returns (uint256) {
    return _totalShares;
  }

  function setTotalPooledEther(uint256 amount) external {
    _totalPooledEther = amount;
  }

  function setTotalShares(uint256 amount) external {
    _totalShares = amount;
  }
}
