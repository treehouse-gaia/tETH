// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import { IContractsRegister } from '../../../../interfaces/gearbox/IContractsRegister.sol';
import { IPoolV3 } from '../../../../interfaces/gearbox/IPoolV3.sol';

/// @title Utility functions and data used in Gearbox actions
contract GearboxHelper {
  error GearboxInvalidPool(address);

  IContractsRegister internal constant CONTRACTS_REGISTER =
    IContractsRegister(0xA50d4E7D8946a7c90652339CDBd262c375d54D99);

  function _checkValidPool(address pool) internal view {
    if (!CONTRACTS_REGISTER.isPool(pool)) revert GearboxInvalidPool(pool);
  }
}
