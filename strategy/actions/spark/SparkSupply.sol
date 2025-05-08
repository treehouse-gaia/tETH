// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Supply a token to an Spark market
/// @dev 0xfc33bf00

contract SparkSupply is ActionBase, SparkHelper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkSupply';

  /// @param amount - amount of token to supply
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

    (uint supplyAmount, bytes memory logData) = _supply(params.amount, params.assetId, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(supplyAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User deposits tokens to the Spark protocol
  /// @dev User needs to approve its wallet to pull the tokens being supplied
  /// @param _amount Amount of tokens to be deposited
  /// @param _assetId The id of the token to be deposited
  /// @param _poolId The id of the pool
  function _supply(uint _amount, uint16 _assetId, uint16 _poolId) internal returns (uint, bytes memory) {
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    address tokenAddr = IPoolV3(_lendingPool).getReserveAddressById(_assetId);

    // if amount is set to max, take the whole _from balance
    if (_amount == type(uint).max) {
      _amount = tokenAddr.getBalance(address(this));
    }

    // approve Spark pool to pull tokens
    tokenAddr.approveToken(address(_lendingPool), _amount);
    IPoolV3(_lendingPool).supply(tokenAddr, _amount, address(this), SPARK_REFERRAL_CODE);

    bytes memory logData = abi.encode(tokenAddr, _amount);
    return (_amount, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
