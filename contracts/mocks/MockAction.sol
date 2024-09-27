// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../strategy/actions/ActionBase.sol';

contract MockAction is ActionBase {
  string constant NAME = 'MockAction';

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  struct Params {
    uint mockNumber;
    address mockAddress;
  }

  event MockActionTriggered(uint number, address addr);

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    uint mockNumber = _parseParamUint(params.mockNumber, _paramMapping[0], _returnValues);

    address mockAddress = _parseParamAddr(params.mockAddress, _paramMapping[1], _returnValues);

    emit MockActionTriggered(mockNumber, mockAddress);

    return bytes32(bytes20(uint160(mockAddress)));
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
