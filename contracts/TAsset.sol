// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import { Blacklistable } from './libs/Blacklistable.sol';
import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';

interface ITAsset {
  function getUnderlying() external view returns (address);
}

/**
 * @notice Treehouse wrapped asset
 */
contract TAsset is ITAsset, ERC4626, ERC20Permit, Ownable2Step, Blacklistable {
  error Unauthorized();

  address private immutable UNDERLYING;

  constructor(
    address _creator,
    IERC20 _underlying,
    string memory _name,
    string memory _symbol
  ) ERC4626(_underlying) ERC20(_name, _symbol) ERC20Permit(_name) Ownable(_creator) {
    UNDERLYING = IInternalAccountingUnit(address(_underlying)).getUnderlying();
  }

  /**
   * @notice Returns the underlying asset of vault
   */
  function getUnderlying() external view returns (address) {
    return UNDERLYING;
  }

  /**
   * @dev Only callable by IAU minters
   */
  function _deposit(address caller, address receiver, uint assets, uint shares) internal virtual override {
    if (!IInternalAccountingUnit(asset()).isMinter(caller)) revert Unauthorized();
    super._deposit(caller, receiver, assets, shares);
  }

  /**
   * @dev Only callable by IAU minters
   */
  function _withdraw(
    address caller,
    address receiver,
    address owner,
    uint256 assets,
    uint256 shares
  ) internal virtual override {
    if (!IInternalAccountingUnit(asset()).isMinter(caller)) revert Unauthorized();
    super._withdraw(caller, receiver, owner, assets, shares);
  }

  /**
   * @dev Will revert blacklisted addresses
   */
  function _update(
    address from,
    address to,
    uint value
  ) internal virtual override notBlacklisted(from) notBlacklisted(to) notBlacklisted(msg.sender) {
    super._update(from, to, value);
  }

  ////////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
    super._transferOwnership(newOwner);
  }

  function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
    return super.decimals();
  }
}
