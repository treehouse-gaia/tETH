// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';

interface IActionRegistry {
  function getAddr(bytes4 _id) external view returns (address);

  function isRegistered(bytes4 _id) external view returns (bool);
}

/**
 * @notice Registry to store and update actions
 */
contract ActionRegistry is IActionRegistry, Ownable2Step {
  error EntryAlreadyExistsError(bytes4);
  error EntryNonExistentError(bytes4);
  error EntryNotInChangeError(bytes4);
  error EmptyPrevAddrError(bytes4);

  event AddNewContract(bytes4, address);
  event RevertToPreviousAddress(address, bytes4, address, address);
  event StartContractChange(address, bytes4, address, address);
  event ApproveContractChange(address, bytes4, address, address);
  event CancelContractChange(address, bytes4, address, address);

  struct Entry {
    address contractAddr;
    bool inContractChange;
    bool exists;
  }

  mapping(bytes4 => Entry) public entries;
  mapping(bytes4 => address) public previousAddresses;
  mapping(bytes4 => address) public pendingAddresses;

  constructor(address _creator) Ownable(_creator) {}

  /**
   * @notice Given an contract id returns the registered
   * @param _id 1st 4 bytes of keccak256 of the contract name
   * @return address of action
   */
  function getAddr(bytes4 _id) public view returns (address) {
    return entries[_id].contractAddr;
  }

  /**
   * @notice helper function to easily query if id is registered
   * @param _id 1st 4 bytes of keccak256 of the contract name
   * @return is action registered
   */
  function isRegistered(bytes4 _id) public view returns (bool) {
    return entries[_id].exists;
  }

  /**
   * @notice adds a new contract to the registry
   * @param _id id of contract
   * @param _contractAddr address of contract
   */
  function addNewContract(bytes4 _id, address _contractAddr) public onlyOwner {
    if (entries[_id].exists) {
      revert EntryAlreadyExistsError(_id);
    }

    entries[_id] = Entry({ contractAddr: _contractAddr, inContractChange: false, exists: true });

    emit AddNewContract(_id, _contractAddr);
  }

  /**
   * @notice reverts to the previous address immediately
   * @dev In case the new version has a fault, a quick way to fallback to the old contract
   * @param _id Id of contract
   */
  function revertToPreviousAddress(bytes4 _id) public onlyOwner {
    if (!(entries[_id].exists)) {
      revert EntryNonExistentError(_id);
    }
    if (previousAddresses[_id] == address(0)) {
      revert EmptyPrevAddrError(_id);
    }

    address currentAddr = entries[_id].contractAddr;
    entries[_id].contractAddr = previousAddresses[_id];

    emit RevertToPreviousAddress(msg.sender, _id, currentAddr, previousAddresses[_id]);
  }

  /**
   * @notice Starts an address change for an existing entry
   * @param _id  Id of contract
   * @param _newContractAddr address of the new contract
   */
  function startContractChange(bytes4 _id, address _newContractAddr) public onlyOwner {
    if (!entries[_id].exists) {
      revert EntryNonExistentError(_id);
    }

    entries[_id].inContractChange = true;
    pendingAddresses[_id] = _newContractAddr;

    emit StartContractChange(msg.sender, _id, entries[_id].contractAddr, _newContractAddr);
  }

  /**
   * @notice Changes new contract address
   * @param _id Id of contract
   */
  function approveContractChange(bytes4 _id) public onlyOwner {
    if (!entries[_id].exists) {
      revert EntryNonExistentError(_id);
    }
    if (!entries[_id].inContractChange) {
      revert EntryNotInChangeError(_id);
    }

    address oldContractAddr = entries[_id].contractAddr;
    entries[_id].contractAddr = pendingAddresses[_id];
    entries[_id].inContractChange = false;

    pendingAddresses[_id] = address(0);
    previousAddresses[_id] = oldContractAddr;

    emit ApproveContractChange(msg.sender, _id, oldContractAddr, entries[_id].contractAddr);
  }

  /**
   * @notice cancel pending change
   * @param _id Id of contract
   */
  function cancelContractChange(bytes4 _id) public onlyOwner {
    if (!entries[_id].exists) {
      revert EntryNonExistentError(_id);
    }
    if (!entries[_id].inContractChange) {
      revert EntryNotInChangeError(_id);
    }

    address oldContractAddr = pendingAddresses[_id];

    pendingAddresses[_id] = address(0);
    entries[_id].inContractChange = false;

    emit CancelContractChange(msg.sender, _id, oldContractAddr, entries[_id].contractAddr);
  }
}
