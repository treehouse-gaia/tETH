// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../ActionBase.sol';

interface IAssertCheck {
  error AssertCheckFailed();
  enum Operation {
    MORE_THAN,
    LESS_THAN,
    EQUAL_TO,
    MORE_THAN_OR_EQUAL_TO,
    LESS_THAN_OR_EQUAL_TO
  }
}

contract AssertCheck is IAssertCheck, ActionBase {
  string constant NAME = 'AssertCheck';

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  struct Params {
    uint expected;
    uint actual;
    Operation operation;
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    uint expected = _parseParamUint(params.expected, _paramMapping[0], _returnValues);
    uint actual = _parseParamUint(params.actual, _paramMapping[1], _returnValues);

    if (params.operation == Operation.MORE_THAN) {
      if (expected <= actual) revert AssertCheckFailed();
    } else if (params.operation == Operation.MORE_THAN_OR_EQUAL_TO) {
      if (expected < actual) revert AssertCheckFailed();
    } else if (params.operation == Operation.EQUAL_TO) {
      if (expected != actual) revert AssertCheckFailed();
    } else if (params.operation == Operation.LESS_THAN_OR_EQUAL_TO) {
      if (expected > actual) revert AssertCheckFailed();
    } else if (params.operation == Operation.LESS_THAN) {
      if (expected >= actual) revert AssertCheckFailed();
    }

    emit ActionEvent(NAME, abi.encode(expected, actual, params.operation));
    return bytes32(0);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
