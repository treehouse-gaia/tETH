// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Payback a token a user borrowed from an Spark market
contract SparkPayback is ActionBase, SparkHelper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkPayback';

  /// @param amount - amount of token to payback
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

    (uint paybackAmount, bytes memory logData) = _payback(params.assetId, params.amount, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(paybackAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User paybacks tokens to the Spark protocol
  /// @dev User needs to approve its wallet to pull the _tokenAddr tokens
  /// @param _assetId The id of the underlying asset to be repaid
  /// @param _amount Amount of tokens to be paid back
  /// @param _poolId The id of the pool
  function _payback(uint16 _assetId, uint _amount, uint16 _poolId) internal returns (uint, bytes memory) {
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    address _poolDataProvider = IProtocolPoolController(PROTOCOL_CONTROLLER).getDataProviderAddress(
      PROTOCOL_ID,
      _poolId
    );
    address tokenAddr = IPoolV3(_lendingPool).getReserveAddressById(_assetId);

    uint maxDebt = getWholeDebt(tokenAddr, address(this), _poolDataProvider);
    _amount = _amount > maxDebt ? maxDebt : _amount;

    tokenAddr.approveToken(_lendingPool, _amount);

    uint tokensBefore = tokenAddr.getBalance(address(this));

    IPoolV3(_lendingPool).repay(tokenAddr, _amount, RATE_MODE_VARIABLE, address(this));

    uint tokensAfter = tokenAddr.getBalance(address(this));

    bytes memory logData = abi.encode(tokenAddr, _amount);
    return (tokensBefore - tokensAfter, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
