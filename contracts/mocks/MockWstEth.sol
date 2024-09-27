// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

/// @dev assume rate of 1:1.1
contract MockWstEth is ERC20Permit {
  address public immutable STETH;
  uint public shares;
  uint public assets;

  constructor(address _stETH) ERC20('wstETH', 'wstETH') ERC20Permit('wstETH') {
    STETH = _stETH;
    assets = 11000;
    shares = 10000;
  }

  function mintTo(address _mintAddress, uint256 _mintAmount) public {
    _mint(_mintAddress, _mintAmount);
  }

  function burnFrom(address _burnAddress, uint256 _burnAmount) public {
    _burn(_burnAddress, _burnAmount);
  }

  // mock steth wrapping 1.1 stETH -> 1 wstETH
  function wrap(uint _amount) external returns (uint) {
    IERC20(STETH).transferFrom(msg.sender, address(this), _amount);
    mintTo(msg.sender, (_amount * shares) / assets);
    return (_amount * shares) / assets;
  }

  // mock price wstETH 1 -> 1.1 stETH
  function getStETHByWstETH(uint _amount) public view returns (uint) {
    return (_amount * assets) / shares;
  }

  function getWstETHByStETH(uint _amount) public view returns (uint) {
    return (_amount * shares) / assets;
  }

  function stEthPerToken() public view returns (uint) {
    return getStETHByWstETH(1e18);
  }

  function setShares(uint _shares) external {
    shares = _shares;
  }

  function setAssets(uint _assets) external {
    assets = _assets;
  }
}
