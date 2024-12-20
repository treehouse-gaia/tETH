// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IVault } from './Vault.sol';
import './libs/Rescuable.sol';

interface IRedemptionController {
  function redeem(uint _amount, address _recipient) external;

  function paused() external view returns (bool);
}

/**
 * @notice Controller to facilitate redemption contracts
 */
contract RedemptionController is Ownable2Step, Pausable, Rescuable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  error Unauthorized();
  error RedemptionUpdateFailed();

  event RedemptionAdded();
  event RedemptionRemoved();

  address public immutable UNDERLYING;
  IVault public immutable VAULT;

  EnumerableSet.AddressSet private _redemptionContracts;
  address public pauser;

  constructor(address _creator, IVault _vault) Ownable(_creator) {
    VAULT = _vault;
    UNDERLYING = _vault.getUnderlying();
  }

  /**
   * Redeem underlying from vault to `_recipient`
   * @dev only redemption contracts
   * @param _amount amount to redeem
   * @param _recipient recipient
   */
  function redeem(uint _amount, address _recipient) external whenNotPaused {
    if (_redemptionContracts.contains(msg.sender) == false) revert Unauthorized();
    IERC20(UNDERLYING).safeTransferFrom(address(VAULT), _recipient, _amount);
  }

  /**
   * Add a redemption contract
   * @param _add new redemption contract address
   */
  function addRedemption(address _add) external onlyOwner {
    bool success = _redemptionContracts.add(_add);
    if (!success) revert RedemptionUpdateFailed();
    emit RedemptionAdded();
  }

  /**
   * Remove a redemption contract
   * @param _remove new redemption contract address
   */
  function removeRedemption(address _remove) external onlyOwner {
    bool success = _redemptionContracts.remove(_remove);
    if (!success) revert RedemptionUpdateFailed();
    emit RedemptionRemoved();
  }

  /**
   * @notice Set the pause state of the contract
   * @dev owner or pauser
   * @param _paused is contract paused
   */
  function setPause(bool _paused) external {
    if (msg.sender != owner() && msg.sender != pauser) revert Unauthorized();

    if (_paused) {
      _pause();
    } else {
      _unpause();
    }
  }

  /**
   * @notice Set a dedicated pauser for the contract
   * @param _pauser pauser address
   */
  function setPauser(address _pauser) external onlyOwner {
    pauser = _pauser;
  }

  /**
   * Returns an array of all redemption contracts
   */
  function getRedemptionContracts() external view returns (address[] memory) {
    return _redemptionContracts.values();
  }

  ////////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
    super._transferOwnership(newOwner);
  }
}
