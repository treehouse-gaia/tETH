// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable2Step.sol';
import { IStrategyExecutor } from './StrategyExecutor.sol';

interface IStrategy {
  error Failed();
  error Unauthorized();

  event StrategyExecutorUpdated(address _newExecutor, address _oldExecutor);

  function execute(address _target, bytes memory _data) external payable returns (bytes32 _response);

  function callExecute(address _target, bytes memory _data) external payable returns (bytes32 _response);

  function vault() external view returns (address);
}

/**
 * @notice strategy contract instance for Treehouse Protocol
 */
contract Strategy is IStrategy, Ownable2Step {
  address public immutable vault;
  address public strategyExecutor;

  constructor(address _creator, address _strategyExecutor, address _vault) Ownable(_creator) {
    strategyExecutor = _strategyExecutor;
    vault = _vault;
  }

  receive() external payable {
    // noOp
  }

  /**
   * @notice danger. executes arbitrary code
   * @param _target target contract
   * @param _data arbitrary calldata
   * @return _response
   */
  function callExecute(address _target, bytes memory _data) external payable returns (bytes32 _response) {
    if (msg.sender != strategyExecutor) revert Unauthorized();
    if (_target == address(0)) revert Failed();

    _response = IStrategy(address(this)).execute(_target, _data);
  }

  /**
   * @notice danger. executes arbitrary code
   * @param _target target contract
   * @param _data arbitrary calldata
   * @return _response
   */
  function execute(address _target, bytes memory _data) external payable returns (bytes32 _response) {
    if (msg.sender != address(this)) revert Unauthorized();

    // call contract in current context
    assembly {
      let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 32)

      // load delegatecall output
      _response := mload(0)

      // throw if delegatecall failed
      if eq(succeeded, 0) {
        revert(0, 0)
      }
    }
  }

  /**
   * @notice set new strategy executor
   * @param _newExecutor set new executor
   */
  function setStrategyExecutor(address _newExecutor) external onlyOwner {
    emit StrategyExecutorUpdated(strategyExecutor, _newExecutor);
    strategyExecutor = _newExecutor;
  }
}
