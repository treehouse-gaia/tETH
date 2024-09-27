// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import '../../interfaces/IWETH9.sol';

library TokenUtils {
  using SafeERC20 for IERC20;

  address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @dev Only approves the amount if allowance is lower than amount, does not decrease allowance
  function approveToken(address _tokenAddr, address _to, uint256 _amount) internal {
    if (_tokenAddr == ETH_ADDR) return;

    if (IERC20(_tokenAddr).allowance(address(this), _to) < _amount) {
      IERC20(_tokenAddr).forceApprove(_to, _amount);
    }
  }

  function depositWeth(uint256 _amount) internal {
    IWETH9(WETH_ADDR).deposit{ value: _amount }();
  }

  function withdrawWeth(uint256 _amount) internal {
    IWETH9(WETH_ADDR).withdraw(_amount);
  }

  function getBalance(address _tokenAddr, address _acc) internal view returns (uint256) {
    if (_tokenAddr == ETH_ADDR) {
      return _acc.balance;
    } else {
      return IERC20(_tokenAddr).balanceOf(_acc);
    }
  }
}
