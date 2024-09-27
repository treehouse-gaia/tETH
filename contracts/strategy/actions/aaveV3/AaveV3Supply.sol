// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/AaveV3Helper.sol';

/// @title Supply a token to an Aave market
/// @dev 0xfc33bf00
contract AaveV3Supply is ActionBase, AaveV3Helper {
  using TokenUtils for address;
  string constant NAME = 'AaveV3Supply';

  /// @param amount - amount of token to supply
  /// @param assetId - id of aave V3 asset
  struct Params {
    uint amount;
    uint16 assetId;
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

    (uint supplyAmount, bytes memory logData) = _supply(params.amount, params.assetId);
    emit ActionEvent(NAME, logData);
    return bytes32(supplyAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User deposits tokens to the Aave protocol
  /// @dev User needs to approve its wallet to pull the tokens being supplied
  /// @param _amount Amount of tokens to be deposited
  /// @param _assetId The id of the token to be deposited
  function _supply(uint _amount, uint16 _assetId) internal returns (uint, bytes memory) {
    IPoolV3 lendingPool = IPoolV3(LENDING_POOL);
    address tokenAddr = lendingPool.getReserveAddressById(_assetId);

    // if amount is set to max, take the whole _from balance
    if (_amount == type(uint).max) {
      _amount = tokenAddr.getBalance(address(this));
    }
    // approve aave pool to pull tokens
    tokenAddr.approveToken(address(lendingPool), _amount);
    lendingPool.supply(tokenAddr, _amount, address(this), AAVE_REFERRAL_CODE);

    bytes memory logData = abi.encode(tokenAddr, _amount);
    return (_amount, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
