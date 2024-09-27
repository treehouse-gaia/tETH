// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/AaveV3Helper.sol';

/// @title Payback a token a user borrowed from an Aave market
contract AaveV3Payback is ActionBase, AaveV3Helper {
  using TokenUtils for address;
  string constant NAME = 'AaveV3Payback';

  /// @param amount - amount of token to payback
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

    (uint paybackAmount, bytes memory logData) = _payback(params.assetId, params.amount);
    emit ActionEvent(NAME, logData);
    return bytes32(paybackAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice User paybacks tokens to the Aave protocol
  /// @dev User needs to approve its wallet to pull the _tokenAddr tokens
  /// @param _assetId The id of the underlying asset to be repaid
  /// @param _amount Amount of tokens to be paid back
  function _payback(uint16 _assetId, uint _amount) internal returns (uint, bytes memory) {
    address tokenAddr = IPoolV3(LENDING_POOL).getReserveAddressById(_assetId);

    uint maxDebt = getWholeDebt(tokenAddr, address(this));
    _amount = _amount > maxDebt ? maxDebt : _amount;

    tokenAddr.approveToken(LENDING_POOL, _amount);

    uint tokensBefore = tokenAddr.getBalance(address(this));

    IPoolV3(LENDING_POOL).repay(tokenAddr, _amount, RATE_MODE_VARIABLE, address(this));

    uint tokensAfter = tokenAddr.getBalance(address(this));

    bytes memory logData = abi.encode(tokenAddr, _amount);
    return (tokensBefore - tokensAfter, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
