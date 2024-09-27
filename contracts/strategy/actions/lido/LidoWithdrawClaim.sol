// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/LidoHelper.sol';
import '../../../interfaces/lido/IwstETH.sol';
import '../../../interfaces/lido/IUnStEth.sol';

/// @title Claim finalized withdrawals
contract LidoWithdrawClaim is ActionBase, LidoHelper {
  using TokenUtils for address;
  string constant NAME = 'LidoWithdrawClaim';

  /// @param requestIds - request ids
  /// @param hints - hints
  struct Params {
    uint[] requestIds;
    uint[] hints;
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory, //unused
    bytes32[] memory //unused
  ) public payable virtual override returns (bytes32) {
    Params memory inputData = parseInputs(_callData);

    (uint claimedEth, bytes memory logData) = _lidoClaimFinalized(inputData);
    emit ActionEvent(NAME, logData);

    return bytes32(claimedEth);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @dev potential lido dust issue
  function _lidoClaimFinalized(Params memory _inputData) internal returns (uint claimedEth, bytes memory logData) {
    uint ethBalanceBefore = TokenUtils.ETH_ADDR.getBalance(address(this));
    IUnStEth(lidoUnStEth).claimWithdrawals(_inputData.requestIds, _inputData.hints);
    uint ethBalanceAfter = TokenUtils.ETH_ADDR.getBalance(address(this));
    claimedEth = ethBalanceAfter - ethBalanceBefore;
    TokenUtils.depositWeth(claimedEth);

    logData = abi.encode(_inputData, claimedEth);
  }

  function parseInputs(bytes memory _callData) internal pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
