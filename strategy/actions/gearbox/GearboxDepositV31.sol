// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/GearboxV31Helper.sol';
import { IPoolV3 } from '../../../interfaces/gearbox/IPoolV3.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Deposit token into gearbox pool
contract GearboxDepositV31 is ActionBase, GearboxV31Helper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'GearboxDepositV31'; // 0xfe19a339

  /// @param assetAmount - deposit amount
  /// @param poolId - pool id of gearbox from ProtocolPoolController
  struct Params {
    uint256 assetAmount;
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
    params.assetAmount = _parseParamUint(params.assetAmount, _paramMapping[0], _returnValues);
    (uint shares, bytes memory logData) = _deposit(params.assetAmount, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(shares);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User deposits tokens into gearbox pool
  /// @param assetAmount Amount of tokens to be deposited
  /// @param _poolId The ID of the pool of gearbox from ProtocolPoolController
  function _deposit(uint assetAmount, uint16 _poolId) internal returns (uint, bytes memory) {
    address _pool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);
    IPoolV3(_pool).asset().approveToken(_pool, assetAmount);

    uint shares = IPoolV3(_pool).deposit(assetAmount, address(this));
    bytes memory logData = abi.encode(_pool, assetAmount, shares);
    return (shares, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
