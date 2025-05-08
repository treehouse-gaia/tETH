// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Borrow a token from Spark market
contract SparkBorrow is ActionBase, SparkHelper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkBorrow';

  /// @param amount - amount of token to borrow
  /// @param assetId - id of Spark asset
  /// @param poolId - pool id of spark
  struct Params {
    uint amount;
    uint16 assetId;
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
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    params.amount = _parseParamUint(params.amount, _paramMapping[0], _returnValues);
    params.assetId = uint16(_parseParamUint(uint16(params.assetId), _paramMapping[1], _returnValues));

    (uint borrowAmount, bytes memory logData) = _borrow(params.assetId, params.amount, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(borrowAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User borrows tokens from the Spark protocol
  /// @param _assetId The id of the token to be borrowed
  /// @param _amount Amount of tokens to be borrowed
  /// @param _poolId The id of the pool
  function _borrow(uint16 _assetId, uint _amount, uint16 _poolId) internal returns (uint, bytes memory) {
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    address tokenAddr = IPoolV3(_lendingPool).getReserveAddressById(_assetId);
    IPoolV3(_lendingPool).borrow(tokenAddr, _amount, RATE_MODE_VARIABLE, SPARK_REFERRAL_CODE, address(this));
    bytes memory logData = abi.encode(tokenAddr, _amount);
    return (_amount, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
