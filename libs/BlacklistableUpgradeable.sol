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

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

/**
 * @notice Allows accounts to be blacklisted by a "blacklister" role
 */
abstract contract BlacklistableUpgradeable is OwnableUpgradeable {
  address public blacklister;
  mapping(address => bool) internal _blacklistedAccounts;

  error NotBlacklister();
  error AccountBlacklisted();
  error ZeroAddress();

  event Blacklisted(address indexed _account);
  event UnBlacklisted(address indexed _account);
  event BlacklisterChanged(address indexed newBlacklister);

  /**
   * @dev Throws if called by any account other than the blacklister.
   */
  modifier onlyBlacklister() {
    if (msg.sender != blacklister) revert NotBlacklister();
    _;
  }

  /**
   * @dev Throws if argument account is blacklisted.
   * @param _account The address to check.
   */
  modifier notBlacklisted(address _account) {
    if (_isBlacklisted(_account)) revert AccountBlacklisted();
    _;
  }

  /**
   * @notice Checks if account is blacklisted.
   * @param _account The address to check.
   * @return True if the account is blacklisted, false if the account is not blacklisted.
   */
  function isBlacklisted(address _account) external view returns (bool) {
    return _isBlacklisted(_account);
  }

  /**
   * @notice Adds account to blacklist.
   * @param _account The address to blacklist.
   */
  function blacklist(address _account) external onlyBlacklister {
    _blacklist(_account);
    emit Blacklisted(_account);
  }

  /**
   * @notice Removes account from blacklist.
   * @param _account The address to remove from the blacklist.
   */
  function unBlacklist(address _account) external onlyBlacklister {
    _unBlacklist(_account);
    emit UnBlacklisted(_account);
  }

  /**
   * @notice Updates the blacklister address.
   * @param _newBlacklister The address of the new blacklister.
   */
  function updateBlacklister(address _newBlacklister) external onlyOwner {
    if (_newBlacklister == address(0)) revert ZeroAddress();
    blacklister = _newBlacklister;
    emit BlacklisterChanged(blacklister);
  }

  /**
   * @dev Checks if account is blacklisted.
   * @param _account The address to check.
   * @return true if the account is blacklisted, false otherwise.
   */
  function _isBlacklisted(address _account) internal view virtual returns (bool) {
    return _blacklistedAccounts[_account];
  }

  /**
   * @dev Helper method that blacklists an account.
   * @param _account The address to blacklist.
   */
  function _blacklist(address _account) internal virtual {
    _blacklistedAccounts[_account] = true;
  }

  /**
   * @dev Helper method that unblacklists an account.
   * @param _account The address to unblacklist.
   */
  function _unBlacklist(address _account) internal virtual {
    _blacklistedAccounts[_account] = false;
  }
}
