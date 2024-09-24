// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/AaveV3Helper.sol';

/// @title Set positions eMode on Aave v3
contract AaveV3SetEMode is ActionBase, AaveV3Helper {
  using TokenUtils for address;
  string constant NAME = 'AaveV3SetEMode';

  /// @param categoryId - eMode category id
  struct Params {
    uint8 categoryId;
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory, // unused
    bytes32[] memory // unused
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);

    (uint categoryId, bytes memory logData) = _setEmode(params.categoryId);
    emit ActionEvent(NAME, logData);
    return bytes32(categoryId);
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User sets EMode for Aave position on its wallet
  /// @param _categoryId eMode category id (0 - 255)
  function _setEmode(uint8 _categoryId) internal returns (uint, bytes memory) {
    IPoolV3(LENDING_POOL).setUserEMode(_categoryId);
    bytes memory logData = abi.encode(_categoryId);
    return (_categoryId, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
