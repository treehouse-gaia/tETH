// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../ActionBase.sol';
import { IStrategy } from '../../Strategy.sol';

interface IVaultWithdrawer {
  function withdraw(address _asset, uint _amount) external;
}

/// @title Pull token from vault
contract VaultPull is ActionBase {
  using SafeERC20 for IERC20;
  string constant NAME = 'VaultPull';

  /// @param token - token to pull
  /// @param amount - amount to pull
  struct Params {
    address token;
    uint amount;
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory, // unused
    bytes32[] memory // unused
  ) public payable virtual override returns (bytes32) {
    Params memory inputData = parseInputs(_callData);
    (uint pulledAmount, bytes memory logData) = _pullToken(inputData);

    emit ActionEvent(NAME, logData);
    return bytes32(pulledAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  //// @notice pulls token from vault. Caller must be aspproved by vault to pull
  function _pullToken(Params memory _inputData) internal returns (uint pulledAmount, bytes memory logData) {
    if (_inputData.amount != 0) {
      IVaultWithdrawer(IStrategy(msg.sender).vault()).withdraw(_inputData.token, _inputData.amount);
      pulledAmount = _inputData.amount;
    }

    logData = abi.encode(_inputData, pulledAmount);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
