// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import { BlacklistableUpgradeable } from './libs/BlacklistableUpgradeable.sol';
import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';

interface ITAsset {
  function getUnderlying() external view returns (address);
}

/**
 * @notice Treehouse wrapped asset
 */
contract TAsset is
  ITAsset,
  ERC4626Upgradeable,
  ERC20PermitUpgradeable,
  Ownable2StepUpgradeable,
  UUPSUpgradeable,
  BlacklistableUpgradeable
{
  error Unauthorized();

  uint private constant VERSION = 1;
  address private UNDERLYING;

  constructor() {
    _disableInitializers();
  }

  function initialize(address _creator, IERC20 _iau, string memory _name, string memory _symbol) public initializer {
    __ERC4626_init(_iau);
    __ERC20_init(_name, _symbol);
    __ERC20Permit_init(_name);
    __Ownable_init(_creator);
    __UUPSUpgradeable_init();

    UNDERLYING = IInternalAccountingUnit(address(_iau)).getUnderlying();
  }

  /**
   * @notice Returns the underlying asset of vault
   */
  function getUnderlying() external view returns (address) {
    return UNDERLYING;
  }

  /**
   * @notice Returns contract version
   */
  function version() public pure returns (uint) {
    return VERSION;
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

  function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

  //////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(
    address newOwner
  ) public virtual override(Ownable2StepUpgradeable, OwnableUpgradeable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2StepUpgradeable, OwnableUpgradeable) {
    super._transferOwnership(newOwner);
  }

  function decimals() public view virtual override(ERC4626Upgradeable, ERC20Upgradeable) returns (uint8) {
    return super.decimals();
  }
}
