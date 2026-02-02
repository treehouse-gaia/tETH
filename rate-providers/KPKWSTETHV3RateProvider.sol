// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity =0.8.24;

import '../interfaces/lido/IwstETH.sol';

interface IERC4626 {
  /**
   * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
   * scenario where all the conditions are met.
   *
   * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
   * - MUST NOT show any variations depending on the caller.
   * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
   * - MUST NOT revert.
   *
   * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
   * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
   * from.
   */
  function convertToAssets(uint256 shares) external view returns (uint256 assets);
}

/**
 * @title Gearbox KPKWSTETHV3 Exchange Rate Provider
 * @notice Returns the value of KPKWSTETHV3 in terms of underlying ETH
 */
contract KPKWSTETHV3RateProvider {
  IwstETH public immutable wstETH;
  IERC4626 public immutable TOKEN;

  constructor(IwstETH _wstETH, IERC4626 _erc4626) {
    wstETH = _wstETH;
    TOKEN = _erc4626;
  }

  /**
   * @return the value of 1 KPKWSTETHV3 token in terms of ETH
   */
  function getRate() external view returns (uint256) {
    return wstETH.getStETHByWstETH(TOKEN.convertToAssets(1e18));
  }
}
