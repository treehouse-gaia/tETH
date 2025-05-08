// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';

import { IVault } from '../Vault.sol';
import { INavRegistry } from '../NavRegistry.sol';
import { IStrategyStorage } from '../strategy/StrategyStorage.sol';
import { INavErc20 } from '../modules/nav/NavErc20.sol';

interface INavLens {
  function vaultNav() external view returns (uint);

  function lastRecordedProtocolNav() external view returns (uint);

  function strategyNav(
    uint strategyId,
    INavRegistry.ModuleParams[] calldata dynamicModuleParams
  ) external view returns (uint);

  function currentProtocolNav(
    INavRegistry.ModuleParams[][] calldata dynamicModuleParams
  ) external view returns (uint _nav);
}

/**
 * View functions for retrieving NAV information
 */
contract NavLens is INavLens {
  error NavModuleNotSet();

  address public immutable VAULT;
  address public immutable UNDERLYING;
  address public immutable T_ASSET;
  address public immutable IAU;
  INavRegistry public immutable NAV_REGISTRY;
  IStrategyStorage public immutable STRATEGY_STORAGE;

  constructor(address _vault, INavRegistry _navRegistry, IStrategyStorage _strategyStorage) {
    UNDERLYING = IVault(_vault).getUnderlying();
    T_ASSET = IVault(_vault).getTAsset();
    VAULT = _vault;
    IAU = IERC4626(T_ASSET).asset();
    NAV_REGISTRY = _navRegistry;
    STRATEGY_STORAGE = _strategyStorage;
  }

  /**
   * @notice vault NAV in terms of the underlying asset
   */
  function vaultNav() public view returns (uint) {
    address erc20NavModule = NAV_REGISTRY.getModuleAddress(0x7bc1fd06);
    if (erc20NavModule == address(0)) revert NavModuleNotSet();

    return INavErc20(erc20NavModule).nav(VAULT, IVault(VAULT).getAllowableAssets());
  }

  /**
   * @notice get NAV of strategyId
   * @param dynamicModuleParams dynamic NAV module metadata
   */
  function strategyNav(
    uint strategyId,
    INavRegistry.ModuleParams[] calldata dynamicModuleParams
  ) public view returns (uint) {
    return NAV_REGISTRY.getStrategyNav(STRATEGY_STORAGE.getStrategyAddress(strategyId), dynamicModuleParams);
  }

  /**
   * @notice last marked NAV
   */
  function lastRecordedProtocolNav() public view returns (uint) {
    return IERC20(IAU).balanceOf(T_ASSET);
  }

  /**
   * current protocol NAV
   * @param dynamicModuleParams dynamic NAV module metadata
   */
  function currentProtocolNav(
    INavRegistry.ModuleParams[][] calldata dynamicModuleParams
  ) external view returns (uint _nav) {
    _nav += vaultNav();
    uint _stratLen = STRATEGY_STORAGE.getStrategyCount();

    for (uint i; i < _stratLen; ++i) {
      _nav += strategyNav(i, dynamicModuleParams[i]);
    }
  }
}
