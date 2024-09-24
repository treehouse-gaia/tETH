// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import { IstETH } from '../interfaces/lido/IstETH.sol';

contract MockStETH is ERC20Permit, IstETH {
  uint256 private _totalPooledEther;
  uint256 private _totalShares;
  bool private _simLidoRoundingBug;

  constructor(uint pooledEther, uint totalShares) ERC20('stETH', 'stETH') ERC20Permit('stETH') {
    _totalPooledEther = pooledEther;
    _totalShares = totalShares;
  }

  receive() external payable {}

  function submit(address) external payable returns (uint256) {
    _mint(msg.sender, _simLidoRoundingBug ? msg.value - 2 : msg.value);

    if (_simLidoRoundingBug) {
      return msg.value / 10;
    }

    return msg.value / 10;
  }

  function setSimLidoRoundingBug(bool present) external {
    _simLidoRoundingBug = present;
  }

  function getPooledEthByShares(uint sharesAmount) external view returns (uint) {
    if (_simLidoRoundingBug) {
      return (sharesAmount * 10) - 2;
    }
    return sharesAmount * 10;
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
