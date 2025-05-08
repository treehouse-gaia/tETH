// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import './MainnetSparkAddresses.sol';
import '../../../../interfaces/aaveV3/IPoolV3.sol';
import '../../../../interfaces/aaveV3/IAaveProtocolDataProvider.sol';
import '../../../../interfaces/aaveV3/IPoolAddressesProvider.sol';

/// @title Utility functions and data used in Spark actions
contract SparkHelper is MainnetSparkAddresses {
  uint16 public constant SPARK_REFERRAL_CODE = 128;
  uint8 internal constant RATE_MODE_VARIABLE = 2;
  uint16 internal constant PROTOCOL_ID = 1;

  /// @dev get variable debt
  function getWholeDebt(
    address _tokenAddr,
    address _debtOwner,
    address _poolDataProvider
  ) internal view virtual returns (uint debt) {
    (, , debt, , , , , , ) = IAaveProtocolDataProvider(_poolDataProvider).getUserReserveData(_tokenAddr, _debtOwner);
  }
}
