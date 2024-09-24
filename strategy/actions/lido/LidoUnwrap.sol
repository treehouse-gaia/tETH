// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/LidoHelper.sol';
import '../../../interfaces/lido/IwstETH.sol';

/// @title Unwrap WStEth and receive StEth
contract LidoUnwrap is ActionBase, LidoHelper {
  using TokenUtils for address;
  string constant NAME = 'LidoUnwrap';

  /// @param amount - amount of WStEth to unwrap
  struct Params {
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
    inputData.amount = _parseParamUint(inputData.amount, _paramMapping[0], _returnValues);

    (uint stEthReceivedAmount, bytes memory logData) = _lidoUnwrap(inputData);
    emit ActionEvent(NAME, logData);
    return bytes32(stEthReceivedAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  function _lidoUnwrap(Params memory _inputData) internal returns (uint stEthReceivedAmount, bytes memory logData) {
    require(_inputData.amount > 0, "Amount to unwrap can't be 0");

    stEthReceivedAmount = IwstETH(payable(lidoWrappedStEth)).unwrap(_inputData.amount);
    logData = abi.encode(_inputData, stEthReceivedAmount);
  }

  function parseInputs(bytes memory _callData) internal pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
