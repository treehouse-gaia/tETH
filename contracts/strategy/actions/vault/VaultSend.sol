// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../ActionBase.sol';
import { IStrategy } from '../../Strategy.sol';

/// @title Send tokens to vault
contract VaultSend is ActionBase {
  using SafeERC20 for IERC20;
  string constant NAME = 'VaultSend';

  /// @param token - token to send
  /// @param amount - amount to send
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
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory inputData = parseInputs(_callData);
    inputData.token = _parseParamAddr(inputData.token, _paramMapping[0], _returnValues);
    inputData.amount = _parseParamUint(inputData.amount, _paramMapping[1], _returnValues);

    (uint sentAmount, bytes memory logData) = _sendToken(inputData);

    emit ActionEvent(NAME, logData);
    return bytes32(sentAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  //// @notice sends token to vault
  function _sendToken(Params memory _inputData) internal returns (uint sentAmount, bytes memory logData) {
    if (_inputData.amount != 0) {
      IERC20(_inputData.token).safeTransfer(IStrategy(msg.sender).vault(), _inputData.amount);
      sentAmount = _inputData.amount;
    }

    logData = abi.encode(_inputData, sentAmount);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
