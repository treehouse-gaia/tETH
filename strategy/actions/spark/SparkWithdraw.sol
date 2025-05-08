// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Withdraw a token from an Spark market
contract SparkWithdraw is ActionBase, SparkHelper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkWithdraw';

  /// @param amount - amount of token to withdraw
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
    bytes calldata callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(callData);
    params.amount = _parseParamUint(params.amount, _paramMapping[0], _returnValues);
    params.assetId = uint16(_parseParamUint(uint16(params.assetId), _paramMapping[1], _returnValues));

    (uint withdrawnAmount, bytes memory logData) = _withdraw(params.assetId, params.amount, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(withdrawnAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User withdraws tokens from the Spark protocol
  /// @param _assetId The id of the token to be deposited
  /// @param _amount Amount of tokens to be withdrawn -> send type(uint).max for whole amount
  /// @param _poolId The id of the pool
  function _withdraw(uint16 _assetId, uint _amount, uint16 _poolId) internal returns (uint, bytes memory) {
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    address tokenAddr = IPoolV3(_lendingPool).getReserveAddressById(_assetId);
    uint withdrawnAmount = IPoolV3(_lendingPool).withdraw(tokenAddr, _amount, address(this));
    bytes memory logData = abi.encode(tokenAddr, withdrawnAmount);
    return (withdrawnAmount, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
