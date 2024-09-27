// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/LidoHelper.sol';

/// @title Supplies ETH (action receives WETH) to Lido for ETH2 Staking. Receives stETH in return
contract LidoStake is ActionBase, LidoHelper {
  using TokenUtils for address;
  string constant NAME = 'LidoStake';

  /// @param amount - amount of eth to supply
  struct Params {
    uint amount;
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
    (uint stEthReceivedAmount, bytes memory logData) = _lidoStake(inputData);

    emit ActionEvent(NAME, logData);
    return bytes32(stEthReceivedAmount);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @notice pulls weth, transforms it into eth, stakes it with lido, receives stEth and sends it to target address
  function _lidoStake(Params memory _inputData) internal returns (uint stEthReceivedAmount, bytes memory logData) {
    TokenUtils.withdrawWeth(_inputData.amount);
    uint stEthBalanceBefore = lidoStEth.getBalance(address(this));
    (bool sent, ) = payable(lidoStEth).call{ value: _inputData.amount }('');
    require(sent, 'Failed to send Ether');
    uint stEthBalanceAfter = lidoStEth.getBalance(address(this));
    stEthReceivedAmount = stEthBalanceAfter - stEthBalanceBefore;
    logData = abi.encode(_inputData, stEthReceivedAmount);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
