// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/LidoHelper.sol';
import '../../../interfaces/lido/IwstETH.sol';

/// @title Wraps either WETH or StEth into WrappedStakedEther (WStEth)
contract LidoWrap is ActionBase, LidoHelper {
  using TokenUtils for address;
  string constant NAME = 'LidoWrap';

  /// @param amount - amount to wrap
  /// @param useWeth - true for using WETH, false for using stEth
  struct Params {
    uint amount;
    bool useWeth;
  }

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

    (uint wStEthReceivedAmount, bytes memory logData) = _lidoWrap(inputData);

    emit ActionEvent(NAME, logData);
    return bytes32(wStEthReceivedAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////
  function _lidoWrap(Params memory _inputData) internal returns (uint wStEthReceivedAmount, bytes memory logData) {
    require(_inputData.amount > 0, "Amount to wrap can't be 0");
    if (_inputData.useWeth) {
      wStEthReceivedAmount = _lidoStakeAndWrapWETH(_inputData);
    } else {
      wStEthReceivedAmount = _lidoWrapStEth(_inputData);
    }

    logData = abi.encode(_inputData, wStEthReceivedAmount);
  }

  function _lidoStakeAndWrapWETH(Params memory _inputData) internal returns (uint wStEthReceivedAmount) {
    TokenUtils.withdrawWeth(_inputData.amount);

    uint wStEthBalanceBefore = lidoWrappedStEth.getBalance(address(this));
    (bool sent, ) = payable(lidoWrappedStEth).call{ value: _inputData.amount }('');
    require(sent, 'Failed to send Ether');
    uint wStEthBalanceAfter = lidoWrappedStEth.getBalance(address(this));

    wStEthReceivedAmount = wStEthBalanceAfter - wStEthBalanceBefore;
  }

  function _lidoWrapStEth(Params memory _inputData) internal returns (uint wStEthReceivedAmount) {
    lidoStEth.approveToken(lidoWrappedStEth, _inputData.amount);
    wStEthReceivedAmount = IwstETH(payable(lidoWrappedStEth)).wrap(_inputData.amount);
  }

  function parseInputs(bytes memory _callData) internal pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
