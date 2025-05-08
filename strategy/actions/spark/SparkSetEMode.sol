// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Set positions eMode on Spark
contract SparkSetEMode is ActionBase, SparkHelper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkSetEMode';

  /// @param categoryId - eMode category id
  /// @param poolId - pool id of spark
  struct Params {
    uint8 categoryId;
    uint16 poolId;
  }

  constructor(address _protocolRegisterAddress) {
    PROTOCOL_CONTROLLER = _protocolRegisterAddress;
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
    Params memory params = parseInputs(_callData);

    (uint categoryId, bytes memory logData) = _setEmode(params.categoryId, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(categoryId);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User sets EMode for Aave position on its wallet
  /// @param _categoryId eMode category id (0 - 255)
  /// @param _poolId The id of the pool
  function _setEmode(uint8 _categoryId, uint16 _poolId) internal returns (uint, bytes memory) {
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    IPoolV3(_lendingPool).setUserEMode(_categoryId);
    bytes memory logData = abi.encode(_categoryId);
    return (_categoryId, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
