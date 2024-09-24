// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import { IActionRegistry } from './ActionRegistry.sol';

/**
 * @notice entrypoint for executing actions. stateless contract meant to use with delegatecall
 */
contract ActionExecutor {
  /// @dev Function sig of ActionBase.executeAction()
  bytes4 public constant EXECUTE_ACTION_SELECTOR = bytes4(keccak256('executeAction(bytes,uint8[],bytes32[])'));
  IActionRegistry public immutable ACTION_REGISTRY;

  error ActionIdNotFound(bytes4);

  constructor(IActionRegistry _actionRegistry) {
    ACTION_REGISTRY = _actionRegistry;
  }

  function executeActions(
    bytes4[] calldata _actionIds,
    bytes[] calldata _actionCallData,
    uint8[][] calldata _paramMapping
  ) public payable {
    bytes32[] memory returnValues = new bytes32[](_actionCallData.length);
    for (uint i; i < _actionIds.length; ++i) {
      returnValues[i] = _executeAction(_actionIds[i], _actionCallData[i], _paramMapping[i], returnValues);
    }
  }

  /**
   * @notice gets the action address and executes it
   * @dev we delegate context of strategy to action contract
   * @param _actionId  action id
   * @param _actionCallData calldata of action
   * @param _paramMapping param mapping of action
   * @param _returnValues return values from previous actions
   */
  function _executeAction(
    bytes4 _actionId,
    bytes calldata _actionCallData,
    uint8[] calldata _paramMapping,
    bytes32[] memory _returnValues
  ) internal returns (bytes32 response) {
    address actionAddr = ACTION_REGISTRY.getAddr(_actionId);
    if (actionAddr == address(0)) revert ActionIdNotFound(_actionId);

    response = delegateCallAndReturnBytes32(
      actionAddr,
      abi.encodeWithSelector(EXECUTE_ACTION_SELECTOR, _actionCallData, _paramMapping, _returnValues)
    );
  }

  function delegateCallAndReturnBytes32(address _target, bytes memory _data) internal returns (bytes32 response) {
    require(_target != address(0));

    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 32)

      // load delegatecall output
      response := mload(0)

      // throw if delegatecall failed
      if eq(succeeded, 0) {
        revert(0, 0)
      }
    }
  }
}
