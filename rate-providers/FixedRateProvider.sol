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

import './IRateProvider.sol';

/**
 * @title Fixed Rate Provider
 * @notice Returns a fixed rate of 1:1
 */
contract FixedRateProvider is IRateProvider {
  /**
   * @return A fixed rate of 1:1
   */
  function getRate() external pure override returns (uint256) {
    return 1e18;
  }
}
