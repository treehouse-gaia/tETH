// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/LidoHelper.sol';
import '../../../interfaces/lido/IwstETH.sol';
import '../../../interfaces/lido/IUnStEth.sol';

/// @title Start stETH/wstETH withdrawal process
contract LidoWithdrawStart is ActionBase, LidoHelper {
  using TokenUtils for address;
  string constant NAME = 'LidoWithdrawStart';

  /// @param amount - amount to withdraw up to 1000e18
  /// @param useWstEth - true for using wstETH, false for using stETH
  struct Params {
    uint amount;
    bool useWStEth;
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
    Params memory inputData = parseInputs(_callData);
    inputData.amount = _parseParamUint(inputData.amount, _paramMapping[0], _returnValues);

    (uint requestId, bytes memory logData) = _lidoWithdraw(inputData);
    emit ActionEvent(NAME, logData);

    return bytes32(requestId);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  function _lidoWithdraw(Params memory _inputData) internal returns (uint requestId, bytes memory logData) {
    uint[] memory _amounts = new uint[](1);
    _amounts[0] = _inputData.amount;

    if (_inputData.useWStEth) {
      TokenUtils.approveToken(lidoWrappedStEth, lidoUnStEth, _inputData.amount);
      requestId = _lidoRequestWithdrawalsWStEth(_amounts)[0];
    } else {
      TokenUtils.approveToken(lidoStEth, lidoUnStEth, _inputData.amount);
      requestId = _lidoRequestWithdrawals(_amounts)[0];
    }

    logData = abi.encode(_inputData, requestId);
  }

  function _lidoRequestWithdrawals(uint[] memory _amount) internal returns (uint[] memory requestIds) {
    return IUnStEth(lidoUnStEth).requestWithdrawals(_amount, address(this));
  }

  function _lidoRequestWithdrawalsWStEth(uint[] memory _amount) internal returns (uint[] memory requestIds) {
    return IUnStEth(lidoUnStEth).requestWithdrawalsWstETH(_amount, address(this));
  }

  function parseInputs(bytes memory _callData) internal pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
