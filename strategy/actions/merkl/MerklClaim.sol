// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../ActionBase.sol';
import { IDistributor } from '../../../interfaces/merkl/IDistributor.sol';

/// @title Action for claiming Merkl rewards
/**
 * @dev Assumptions:
 * - only recipient, or whitelisted operators, can claim rewards for recipient
 * - length size of inputs ARE checked in merkl distributor
 * - tokens and amounts are encoded in the proofs; if the token amounts are wrong code will revert
 * - claimable amounts PASSED IN as assumed to be totals, the amount sent to treasury will be the available unclaimed portion in merkl
 */
contract MerklClaim is ActionBase {
  using SafeERC20 for IERC20;

  error OnlyRecipient();

  IDistributor constant MERKL_DISTRIBUTOR = IDistributor(0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae);
  address constant TREASURY = 0xB38f2aCb7B562475908c0C6E80a045Deb4023f70;

  string constant NAME = 'MerklClaim'; // 0x79b06cc7

  /// @param users - from the merkl api
  /// @param tokens - from the merkl api
  /// @param amounts - from the merkl api
  /// @param proofs - from the merkl api
  /// @param toTreasury - whether to send to treasury
  struct Params {
    address[] users;
    address[] tokens;
    uint256[] amounts;
    bytes32[][] proofs;
    bool[] toTreasury;
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory,
    bytes32[] memory
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    (uint void, bytes memory logData) = _claim(
      params.users,
      params.tokens,
      params.amounts,
      params.proofs,
      params.toTreasury
    );
    emit ActionEvent(NAME, logData);
    return bytes32(void);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////

  /// @param users Recipient of tokens
  /// @param tokens ERC20 claimed
  /// @param amounts Amount of tokens that will be sent to the corresponding users
  /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
  /// @param toTreasury Whether to send the claimed tokens to treasury
  function _claim(
    address[] memory users,
    address[] memory tokens,
    uint256[] memory amounts,
    bytes32[][] memory proofs,
    bool[] memory toTreasury
  ) internal returns (uint, bytes memory) {
    uint256[] memory claimed = new uint256[](tokens.length);

    for (uint i; i < tokens.length; ++i) {
      if (users[i] != address(this)) revert OnlyRecipient();

      if (toTreasury[i]) {
        (uint208 _claimed, , ) = MERKL_DISTRIBUTOR.claimed(address(this), tokens[i]);
        claimed[i] = _claimed;
      }
    }

    MERKL_DISTRIBUTOR.claim(users, tokens, amounts, proofs);

    for (uint i; i < tokens.length; ++i) {
      if (toTreasury[i]) {
        IERC20(tokens[i]).safeTransfer(TREASURY, amounts[i] - claimed[i]);
      }
    }

    bytes memory logData = abi.encode(tokens, amounts, toTreasury);
    return (0, logData);
  }

  function parseInputs(bytes calldata _callData) public pure returns (Params memory params) {
    (
      address[] memory users,
      address[] memory tokens,
      uint256[] memory amounts,
      bytes32[][] memory proofs,
      bool[] memory toTreasury
    ) = abi.decode(_callData, (address[], address[], uint256[], bytes32[][], bool[]));

    params.users = users;
    params.tokens = tokens;
    params.amounts = amounts;
    params.proofs = proofs;
    params.toTreasury = toTreasury;
  }
}
