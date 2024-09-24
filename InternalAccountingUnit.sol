// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

interface IInternalAccountingUnit {
  error NotMinter();
  error Unauthorized();
  error UpdateMinterFailed();

  event Burned(address indexed _from, address indexed _to, uint _amount);
  event Minted(address indexed _from, address indexed _to, uint _amount);
  event MinterAdded(address _minter);
  event MinterRemoved(address _minter);
  event TimelockChanged(address _timelock);

  function timelock() external returns (address);

  function burn(uint _burnAmount) external;

  function burnFrom(address _burnAddress, uint _burnAmount) external;

  function mintTo(address _mintAddress, uint _mintAmount) external;

  function getUnderlying() external view returns (address);

  function getMinters() external view returns (address[] memory);

  function isMinter(address _address) external view returns (bool);
}

/**
 * @notice Internal accounting unit to track balances
 */
contract InternalAccountingUnit is IInternalAccountingUnit, ERC20, Ownable2Step {
  using EnumerableSet for EnumerableSet.AddressSet;

  address private immutable UNDERLYING;
  address public timelock;
  EnumerableSet.AddressSet private _minters;

  constructor(
    address _creator,
    IERC20Metadata _underlying
  )
    ERC20(string.concat('InternalAccountingUnit_', _underlying.name()), string.concat('IAU_', _underlying.symbol()))
    Ownable(_creator)
  {
    UNDERLYING = address(_underlying);
  }

  modifier onlyMinters() {
    if (!_minters.contains(msg.sender)) revert NotMinter();
    _;
  }

  /**
   * @notice burn `_burnAmount` from caller
   * @param _burnAmount amount to burn
   */
  function burn(uint _burnAmount) external onlyMinters {
    _burn(msg.sender, _burnAmount);
    emit Burned(msg.sender, address(0), _burnAmount);
  }

  /**
   * @notice burn `_burnAmount` from `_burnAddress`
   * @param _burnAddress address to burn from
   * @param _burnAmount amount to burn
   */
  function burnFrom(address _burnAddress, uint _burnAmount) external onlyMinters {
    _burn(_burnAddress, _burnAmount);
    emit Burned(_burnAddress, address(0), _burnAmount);
  }

  /**
   * @notice mints `_mintAmount` to `_mintAddress`
   * @param _mintAddress address to mint to
   * @param _mintAmount amount to mint
   */
  function mintTo(address _mintAddress, uint _mintAmount) external onlyMinters {
    _mint(_mintAddress, _mintAmount);
    emit Minted(address(0), _mintAddress, _mintAmount);
  }

  /**
   * @notice add address as minter
   * @param _newMinter address to add
   */
  function addMinter(address _newMinter) external onlyOwner {
    bool success = _minters.add(_newMinter);
    if (!success) revert UpdateMinterFailed();
    emit MinterAdded(_newMinter);
  }

  /**
   * @notice remove address as minter
   * @param _oldMinter address to remove
   */
  function removeMinter(address _oldMinter) external onlyOwner {
    bool success = _minters.remove(_oldMinter);
    if (!success) revert UpdateMinterFailed();
    emit MinterRemoved(_oldMinter);
  }

  /**
   * @notice set a timelock address
   * @param _newTimelock timelock address
   */
  function setTimelock(address _newTimelock) external onlyOwner {
    timelock = _newTimelock;
    emit TimelockChanged(_newTimelock);
  }

  /**
   * @notice Returns the underlying asset of vault
   */
  function getUnderlying() external view returns (address) {
    return UNDERLYING;
  }

  /**
   * @notice get list of minter addresses
   * @return list of minter addresses
   */
  function getMinters() external view returns (address[] memory) {
    return _minters.values();
  }

  /**
   * @notice check if address can mint/burn
   * @param _address address to check
   * @return true if address is minter
   */
  function isMinter(address _address) external view returns (bool) {
    return _minters.contains(_address);
  }

  ////////////////////// Inheritance overrides ////////////////////////

  function _update(address from, address to, uint value) internal virtual override {
    if (!(_minters.contains(from) || _minters.contains(to) || _minters.contains(msg.sender))) revert Unauthorized();
    super._update(from, to, value);
  }

  /// @dev override onlyOwner to include timelock
  function _checkOwner() internal view virtual override {
    if (owner() != _msgSender() && _msgSender() != timelock) {
      revert OwnableUnauthorizedAccount(_msgSender());
    }
  }
}
