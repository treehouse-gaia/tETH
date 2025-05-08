// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../ActionBase.sol';
import { IDistributor } from '../../../interfaces/merkl/IDistributor.sol';

/// @title Action for claiming Merkl rewards
contract MerklToggleOperator is ActionBase {
  IDistributor constant MERKL_DISTRIBUTOR = IDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);

  string constant NAME = 'MerklToggleOperator'; // 0x3c3bfe98

  /// @param operator - operator that can claim rewards on behalf of user
  struct Params {
    address operator;
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory,
    bytes32[] memory
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    (bool success, bytes memory logData) = _toggle(params.operator);
    emit ActionEvent(NAME, logData);
    return bytes32(abi.encodePacked(success));
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice Toggle an operator that can claim rewards for recipient
  function _toggle(address operator) internal returns (bool isAuthorized, bytes memory) {
    MERKL_DISTRIBUTOR.toggleOperator(address(this), operator);
    isAuthorized = MERKL_DISTRIBUTOR.operators(address(this), operator);
    bytes memory logData = abi.encode(address(this), operator, isAuthorized);
    return (isAuthorized, logData);
  }

  function parseInputs(bytes calldata _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
