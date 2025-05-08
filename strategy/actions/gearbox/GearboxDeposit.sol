// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/GearboxHelper.sol';
import { IPoolV3 } from '../../../interfaces/gearbox/IPoolV3.sol';

/// @title Deposit token into gearbox pool
contract GearboxDeposit is ActionBase, GearboxHelper {
  using TokenUtils for address;

  string constant NAME = 'GearboxDeposit'; // 0x9dad660c

  /// @param pool - pool/vault address of gearbox
  /// @param assetAmount - deposit amount
  struct Params {
    address pool;
    uint256 assetAmount;
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
    (uint shares, bytes memory logData) = _deposit(params.pool, params.assetAmount);
    emit ActionEvent(NAME, logData);
    return bytes32(shares);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User deposits tokens into gearbox pool
  /// @param pool The address of the deposit vault
  /// @param assetAmount Amount of tokens to be deposited
  function _deposit(address pool, uint assetAmount) internal returns (uint, bytes memory) {
    _checkValidPool(pool);
    IPoolV3(pool).asset().approveToken(pool, assetAmount);

    uint shares = IPoolV3(pool).deposit(assetAmount, address(this));
    bytes memory logData = abi.encode(pool, assetAmount, shares);
    return (shares, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
