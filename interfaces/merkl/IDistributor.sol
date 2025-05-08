// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

// https://etherscan.io/address/0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae#readProxyContract
interface IDistributor {
  /// @notice Claims rewards for a given set of users
  /// @dev Anyone may call this function for anyone else, funds go to destination regardless, it's just a question of
  /// who provides the proof and pays the gas: `msg.sender` is used only for addresses that require a trusted operator
  /// @param users Recipient of tokens
  /// @param tokens ERC20 claimed
  /// @param amounts Amount of tokens that will be sent to the corresponding users
  /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
  function claim(
    address[] calldata users,
    address[] calldata tokens,
    uint256[] calldata amounts,
    bytes32[][] calldata proofs
  ) external;

  /// @notice Toggles whitelisting for a given user and a given operator
  function toggleOperator(address user, address operator) external;

  function operators(address user, address operator) external view returns (bool isAuthorized);

  function claimed(
    address user,
    address token
  ) external view returns (uint208 amount, uint48 timestamp, bytes32 merkleRoot);
}
