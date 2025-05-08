// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/GearboxHelper.sol';
import { IPoolV3 } from '../../../interfaces/gearbox/IPoolV3.sol';

/// @title Redeem gearbox receipt token
contract GearboxRedeem is ActionBase, GearboxHelper {
  using TokenUtils for address;

  string constant NAME = 'GearboxRedeem'; // 0x088ea16d

  /// @param pool - pool/vault address of gearbox
  /// @param shareAmount - no. of shares to redeem
  struct Params {
    address pool;
    uint256 shareAmount;
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
    (uint assets, bytes memory logData) = _redeem(params.pool, params.shareAmount);
    emit ActionEvent(NAME, logData);
    return bytes32(assets);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User redeems vault share for asset tokens
  /// @param pool The address of the deposit vault
  /// @param shareAmount Amount of shares to redeem for assets
  function _redeem(address pool, uint shareAmount) internal returns (uint, bytes memory) {
    _checkValidPool(pool);
    uint assets = IPoolV3(pool).redeem(shareAmount, address(this), address(this));
    bytes memory logData = abi.encode(pool, shareAmount, assets);
    return (assets, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
