// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

contract MockErc20 is ERC20Permit, ERC20Burnable {
  uint8 _decimals = 18;

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_name) {}

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  // mock steth wrapping 1.1 stETH -> 1 wstETH
  function wrap(uint _amount) external pure returns (uint) {
    return (_amount * 10000) / 11000;
  }

  // mock price wstETH 1 -> 1.1 stETH
  function getStETHByWstETH(uint _amount) external pure returns (uint) {
    return (_amount * 11000) / 10000;
  }

  function setDecimals(uint8 _newDecimals) external {
    _decimals = _newDecimals;
  }

  function burnFrom(address _burnAddress, uint256 _burnAmount) public override(ERC20Burnable) {
    super._burn(_burnAddress, _burnAmount);
  }

  function mintTo(address _mintAddress, uint256 _mintAmount) public {
    super._mint(_mintAddress, _mintAmount);
  }
}
