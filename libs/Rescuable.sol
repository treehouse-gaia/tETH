/**
 * SPDX-License-Identifier: Apache-2.0
 *
 * Copyright (c) 2023, Circle Internet Financial, LLC.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

abstract contract Rescuable is Ownable {
  using SafeERC20 for IERC20;

  address private _rescuer;

  error NotRescuer();
  error RescueFailed();

  event RescuerChanged(address indexed newRescuer);

  /**
   * @notice Returns current rescuer
   * @return Rescuer's address
   */
  function rescuer() external view returns (address) {
    return _rescuer;
  }

  /**
   * @notice Revert if called by any account other than the rescuer.
   */
  modifier onlyRescuer() {
    if (msg.sender != _rescuer) revert NotRescuer();
    _;
  }

  /**
   * @notice Rescue ERC20 tokens locked up in this contract.
   * @param tokenContract ERC20 token contract address
   * @param to        Recipient address
   * @param amount    Amount to withdraw
   */
  function rescueERC20(IERC20 tokenContract, address to, uint256 amount) external onlyRescuer {
    tokenContract.safeTransfer(to, amount);
  }

  /**
   * @notice Rescue native token locked up in this contract.
   * @param to        Recipient address
   */
  function rescueETH(address to) external onlyRescuer {
    (bool success, ) = address(to).call{ value: address(this).balance }('');

    if (!success) revert RescueFailed();
  }

  /**
   * @notice Updates the rescuer address.
   * @param newRescuer The address of the new rescuer.
   */
  function updateRescuer(address newRescuer) external onlyOwner {
    _rescuer = newRescuer;
    emit RescuerChanged(newRescuer);
  }
}
