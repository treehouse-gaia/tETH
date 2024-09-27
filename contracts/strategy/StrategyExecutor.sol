// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IStrategy } from './Strategy.sol';
import { IStrategyStorage } from './StrategyStorage.sol';

interface IStrategyExecutor {
  error Unauthorized();
  error StrategyNotActive();
  error ArrayLengthMismatch();
  error ActionNotWhitelisted();
  error Failed();

  event ExecutorUpdated(address indexed _executor, bool _isActive);
  event ExecutionEvent(bytes4[], uint _strategyId);
}

/**
 * @notice Entry point for executing actions on strategies
 */
contract StrategyExecutor is IStrategyExecutor, Ownable2Step {
  /// @dev Function sig of ActionExecutor.executeActions()
  bytes4 public constant EXECUTE_ACTIONS_SELECTOR = bytes4(keccak256('executeActions(bytes4[],bytes[],uint8[][])'));

  address public immutable ACTION_EXECUTOR;
  IStrategyStorage public immutable STRATEGY_STORAGE;

  mapping(address => bool) public executors;

  constructor(address _creator, address _actionExecutor, IStrategyStorage _strategyStorage) Ownable(_creator) {
    ACTION_EXECUTOR = _actionExecutor;
    STRATEGY_STORAGE = _strategyStorage;
  }

  /**
   * @notice function to execute actions on stragies
   * @param _strategyId strategyId of strategy in storage
   * @param _actionIds list of actionIds
   * @param _actionCalldata list of encoded calldata for actions
   * @param _paramMapping list of param mappings for actions
   */
  function executeOnStrategy(
    uint _strategyId,
    bytes4[] calldata _actionIds,
    bytes[] calldata _actionCalldata,
    uint8[][] memory _paramMapping
  ) external payable {
    if (executors[msg.sender] != true) revert Unauthorized();

    address _stratAddress = STRATEGY_STORAGE.getStrategyAddress(_strategyId);
    if (STRATEGY_STORAGE.isActiveStrategy(_stratAddress) == false) revert StrategyNotActive();
    if (_actionCalldata.length != _actionIds.length) revert ArrayLengthMismatch();

    for (uint i; i < _actionIds.length; ) {
      if (STRATEGY_STORAGE.isActionWhitelisted(_stratAddress, _actionIds[i]) == false) revert ActionNotWhitelisted();
      unchecked {
        ++i;
      }
    }

    IStrategy(_stratAddress).callExecute(
      ACTION_EXECUTOR,
      abi.encodeWithSelector(EXECUTE_ACTIONS_SELECTOR, _actionIds, _actionCalldata, _paramMapping)
    );

    emit ExecutionEvent(_actionIds, _strategyId);
  }

  /**
   * @notice update addresses that can execute strategies
   * @param _executor address of executor
   * @param _isActive false = inactive, true = active
   */
  function updateExecutor(address _executor, bool _isActive) external onlyOwner {
    executors[_executor] = _isActive;
    emit ExecutorUpdated(_executor, _isActive);
  }
}
