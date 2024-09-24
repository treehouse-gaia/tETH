// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/interfaces/IERC20.sol';
import { IStrategyStorage } from './StrategyStorage.sol';

interface IStrategy {
  error Failed();
  error Unauthorized();

  function execute(address _target, bytes memory _data) external payable returns (bytes32 _response);

  function callExecute(address _target, bytes memory _data) external payable returns (bytes32 _response);

  function vault() external view returns (address);
}

/**
 * @notice strategy contract instance for Treehouse Protocol
 */
contract Strategy is IStrategy {
  address public immutable vault;
  IStrategyStorage public immutable strategyStorage;

  constructor(IStrategyStorage _strategyStorage, address _vault) {
    strategyStorage = _strategyStorage;
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
    if (msg.sender != strategyStorage.strategyExecutor()) revert Unauthorized();
    if (_target == address(0)) revert Failed();

    _response = IStrategy(address(this)).execute{ value: msg.value }(_target, _data);
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
}
