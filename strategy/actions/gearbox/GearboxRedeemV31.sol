// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/GearboxV31Helper.sol';
import { IPoolV3 } from '../../../interfaces/gearbox/IPoolV3.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

/// @title Redeem gearbox receipt token
contract GearboxRedeemV31 is ActionBase, GearboxV31Helper {
  using TokenUtils for address;
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'GearboxRedeemV31'; //0x675cde8b

  /// @param shareAmount - no. of shares to redeem
  /// @param poolId - pool id of gearbox from ProtocolPoolController
  struct Params {
    uint256 shareAmount;
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
    params.shareAmount = _parseParamUint(params.shareAmount, _paramMapping[0], _returnValues);
    (uint assets, bytes memory logData) = _redeem(params.shareAmount, params.poolId);
    emit ActionEvent(NAME, logData);
    return bytes32(assets);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User redeems vault share for asset tokens
  /// @param shareAmount Amount of shares to redeem for assets
  /// @param _poolId The ID of the pool of gearbox from ProtocolPoolController
  function _redeem(uint shareAmount, uint16 _poolId) internal returns (uint, bytes memory) {
    address _pool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, _poolId);

    uint assets = IPoolV3(_pool).redeem(shareAmount, address(this), address(this));
    bytes memory logData = abi.encode(_pool, shareAmount, assets);
    return (assets, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
