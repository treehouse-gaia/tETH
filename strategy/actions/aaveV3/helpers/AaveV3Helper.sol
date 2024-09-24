// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import './MainnetAaveV3Addresses.sol';
import '../../../../interfaces/aaveV3/IPoolV3.sol';
import '../../../../interfaces/aaveV3/IAaveProtocolDataProvider.sol';
import '../../../../interfaces/aaveV3/IPoolAddressesProvider.sol';

/// @title Utility functions and data used in AaveV3 actions
contract AaveV3Helper is MainnetAaveV3Addresses {
  uint16 internal constant AAVE_REFERRAL_CODE = 0;
  uint8 internal constant RATE_MODE_VARIABLE = 2;

  /// @dev get variable debt
  function getWholeDebt(address _tokenAddr, address _debtOwner) internal view virtual returns (uint debt) {
    (, , debt, , , , , , ) = IAaveProtocolDataProvider(POOL_DATA_PROVIDER).getUserReserveData(_tokenAddr, _debtOwner);
  }
}
