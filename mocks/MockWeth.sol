// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import { IWETH9 } from '../interfaces/IWETH9.sol';

contract MockWeth is ERC20Burnable, IWETH9 {
  uint8 _decimals = 18;

  constructor() ERC20('MOCK_WETH', 'MOCK_WETH') {}

  function burnFrom(address _burnAddress, uint256 _burnAmount) public override(ERC20Burnable) {
    _burn(_burnAddress, _burnAmount);
  }

  function deposit() external payable {
    super._mint(msg.sender, msg.value);
  }

  function withdraw(uint256 wad) external {
    _burn(msg.sender, wad);
    (bool success, ) = address(msg.sender).call{ value: wad }('');

    if (!success) revert('Withdraw failed');
  }
}
