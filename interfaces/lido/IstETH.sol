// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://docs.lido.fi/contracts/lido
/// @dev https://etherscan.io/address/0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
interface IstETH {
  /**
   * @notice Send funds to the pool with optional _referral parameter
   * @dev This function is alternative way to submit funds. Supports optional referral address.
   * @return Amount of StETH shares generated
   */
  function submit(address _referral) external payable returns (uint256);

  /**
   * @notice get the current share rate by dividing the total amount of pooled ether by total shares
   * @param _sharesAmount amount of shares
   * @return the amount of Ether that corresponds to `_sharesAmount` token shares.
   */
  function getPooledEthByShares(uint _sharesAmount) external view returns (uint);
}
