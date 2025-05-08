// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

interface INavRegistry {
  struct ModuleParams {
    bytes4 moduleId;
    bytes cd;
  }

  struct Enumerable {
    EnumerableSet.Bytes32Set moduleIds;
  }

  // modules
  function getModuleIds() external view returns (bytes4[] memory);

  function getModuleDetails(bytes4 moduleId) external view returns (address, string memory);

  function getModuleAddress(bytes4 moduleId) external view returns (address);

  function isModuleRegistered(bytes4 moduleId) external view returns (bool);

  // nav
  function getStrategyModules(address strategy) external view returns (bytes4[] memory moduleIds);

  function getStrategyModuleCalldata(address strategy, bytes4 moduleId) external view returns (bytes memory);

  function getStrategyNav(
    address strategy,
    ModuleParams[] calldata dynamicModuleParams
  ) external view returns (uint navInUnderlying);
}

contract NavRegistry is INavRegistry, Ownable2Step {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  bytes32 public constant DYNAMIC = keccak256('NavRegistry.dynamic');

  error EntryAlreadyExistsError(bytes4);
  error EntryNonExistentError(bytes4);
  error EmptyPrevAddrError(bytes4);
  error GetNavFailed(bytes4);
  error AlreadyAttached(bytes4);
  error NotAttached(bytes4);
  error MissingDynamicModule(bytes4);

  event AddNewContract(bytes4, address);
  event UpdateContract(bytes4, address active, address old);
  event RevertToPreviousAddress(bytes4, address active, address old);

  struct Entry {
    address addr;
    bool exists;
    string name;
  }

  mapping(bytes4 moduleId => Entry entries) public modules;
  mapping(bytes4 moduleId => address) public previousModuleAddresses;
  bytes4[] private _moduleIds;

  mapping(address strategy => mapping(bytes4 moduleId => bytes cd)) public strategyModuleCd;
  mapping(address strategy => Enumerable moduleIds) private _strategyModuleIds;

  constructor() Ownable(msg.sender) {}

  //////////////////////////// Modules ////////////////////////////
  /**
   * @notice Returns list of module ids
   */
  function getModuleIds() external view returns (bytes4[] memory) {
    return _moduleIds;
  }

  /**
   * @notice Returns registered contract details
   * @param id id of contract
   * @return address and name of contract
   */
  function getModuleDetails(bytes4 id) external view returns (address, string memory) {
    return (modules[id].addr, modules[id].name);
  }

  /**
   * @notice Returns registered contract given id
   * @param id id of contract
   * @return address of contract
   */
  function getModuleAddress(bytes4 id) external view returns (address) {
    return modules[id].addr;
  }

  /**
   * @notice Helper function to query if id is registered
   * @param id 1st 4 bytes of keccak256 of the contract name
   * @return is id registered
   */
  function isModuleRegistered(bytes4 id) public view returns (bool) {
    return modules[id].exists;
  }

  /**
   * @notice Adds a new contract to the registry
   * @param id id of contract
   * @param addr address of contract to register
   * @param name human readable module name
   */
  function registerModule(bytes4 id, address addr, string calldata name) external onlyOwner {
    if (modules[id].exists) {
      revert EntryAlreadyExistsError(id);
    }

    modules[id] = Entry({ addr: addr, exists: true, name: name });
    _moduleIds.push(id);

    emit AddNewContract(id, addr);
  }

  /**
   * @notice Starts an address change for an existing entry
   * @param id Id of contract
   * @param newAddr address of the new contract
   * @param name human readable module name
   */
  function updateModule(bytes4 id, address newAddr, string calldata name) external onlyOwner {
    if (!modules[id].exists) {
      revert EntryNonExistentError(id);
    }
    address _oldAddr = modules[id].addr;
    previousModuleAddresses[id] = _oldAddr;
    modules[id].addr = newAddr;
    modules[id].name = name;

    emit UpdateContract(id, newAddr, _oldAddr);
  }

  /**
   * @notice reverts to the previous address immediately
   * @dev In case the new version has a fault, a quick way to fallback to the old contract
   * @param id Id of contract
   */
  function revertModule(bytes4 id) external onlyOwner {
    if (!(modules[id].exists)) {
      revert EntryNonExistentError(id);
    }
    if (previousModuleAddresses[id] == address(0)) {
      revert EmptyPrevAddrError(id);
    }

    address currentAddr = modules[id].addr;
    modules[id].addr = previousModuleAddresses[id];

    emit RevertToPreviousAddress(id, modules[id].addr, currentAddr);
  }

  //////////////////////////// Strategies ////////////////////////////

  /**
   * @notice Attaches a module to a strategy
   * @param strategy strategy address to attach module
   * @param params module parameters
   */
  function attachTo(address strategy, ModuleParams calldata params) external onlyOwner {
    if (_strategyModuleIds[strategy].moduleIds.add(params.moduleId) == false) revert AlreadyAttached(params.moduleId);
    strategyModuleCd[strategy][params.moduleId] = params.cd;
  }

  /**
   * @notice Detaches a module from a strategy
   * @param strategy strategy address to detach module from
   * @param moduleId 4-byte module id
   */
  function detachFrom(address strategy, bytes4 moduleId) external onlyOwner {
    if (_strategyModuleIds[strategy].moduleIds.remove(moduleId) == false) revert NotAttached(moduleId);
    delete strategyModuleCd[strategy][moduleId];
  }

  /**
   * @notice Update an attached strategy's parameters
   * @param strategy strategy address
   * @param params updated module parameters
   */
  function updateParams(address strategy, ModuleParams calldata params) external onlyOwner {
    if (_strategyModuleIds[strategy].moduleIds.contains(params.moduleId) == false) revert NotAttached(params.moduleId);
    strategyModuleCd[strategy][params.moduleId] = params.cd;
  }

  /**
   * @notice Get module Ids attached to a particular strategy
   * @param strategy strategy address
   * @return moduleIds array of 4-byte module ids
   */
  function getStrategyModules(address strategy) external view returns (bytes4[] memory moduleIds) {
    uint _len = _strategyModuleIds[strategy].moduleIds.length();
    moduleIds = new bytes4[](_len);
    for (uint i; i < _len; ++i) {
      moduleIds[i] = bytes4(_strategyModuleIds[strategy].moduleIds.at(i));
    }
  }

  /**
   * @notice Get calldata of module attached to strategy
   * @param strategy strategy address
   * @param moduleId 4-byte module Id
   * @return _calldata array of 4-byte module ids
   */
  function getStrategyModuleCalldata(address strategy, bytes4 moduleId) external view returns (bytes memory) {
    if (_strategyModuleIds[strategy].moduleIds.contains(moduleId) == false) revert NotAttached(moduleId);

    return strategyModuleCd[strategy][moduleId];
  }

  /**
   * @notice Get Nav of a strategy
   *
   * @dev loop `moduleIds.length` times, if module is dynamic,
   * loop dynamicModuleParams to retrieve first instance of moduleId + cd.
   * dynamicModuleParams must not have duplicates.
   *
   * @param strategy strategy address
   * @param dynamicModuleParams array of dynamic module params
   * @return _navInUnderlying sum of all attached modules
   */
  function getStrategyNav(
    address strategy,
    ModuleParams[] calldata dynamicModuleParams
  ) external view returns (uint _navInUnderlying) {
    uint256 moduleIdsLength = _strategyModuleIds[strategy].moduleIds.length();
    for (uint i; i < moduleIdsLength; ++i) {
      bytes4 moduleId = bytes4(_strategyModuleIds[strategy].moduleIds.at(i));
      if (bytes32(strategyModuleCd[strategy][moduleId]) != DYNAMIC) {
        (bool success, bytes memory info) = address(modules[moduleId].addr).staticcall(
          strategyModuleCd[strategy][moduleId]
        );

        if (!success) revert GetNavFailed(moduleId);

        unchecked {
          _navInUnderlying += uint(bytes32(info));
        }
      } else {
        // get first instance of dynamic cd
        bool executed = false;

        for (uint j; j < dynamicModuleParams.length; ++j) {
          if (dynamicModuleParams[j].moduleId == moduleId) {
            (bool success, bytes memory info) = address(modules[moduleId].addr).staticcall(dynamicModuleParams[j].cd);
            if (!success) revert GetNavFailed(moduleId);

            unchecked {
              _navInUnderlying += uint(bytes32(info));
            }

            executed = true;
            break;
          }
        }

        if (!executed) revert MissingDynamicModule(moduleId);
      }
    }
  }
}
