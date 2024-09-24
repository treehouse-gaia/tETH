// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './libs/Rescuable.sol';
import { ITAsset } from './TAsset.sol';
import { IStrategyStorage } from './strategy/StrategyStorage.sol';
import { IWETH9 } from './interfaces/IWETH9.sol';
import { IRateProviderRegistry } from './rate-providers/RateProviderRegistry.sol';

interface IVault {
  error InvalidStrategy();
  error InvalidAddress();
  error UnsupportedDecimals();
  error Failed();

  event StrategyStorageUpdated(address indexed _new, address _old);
  event RedemptionUpdated(address indexed _new, address _old);
  event AllowableAssetAdded(address _asset);
  event AllowableAssetRemoved(address _asset);

  function getAllowableAssets() external view returns (address[] memory);

  function getAllowableAssetCount() external view returns (uint);

  function isAllowableAsset(address _asset) external view returns (bool);

  function getTAsset() external view returns (address);

  function getUnderlying() external view returns (address);

  function withdraw(address _asset, uint _amount) external;
}

/**
 * @notice Core contract that holds protocol assets when not deployed to strategies
 * @dev deposits are assumed to be implicit via ERC20 transfers into this contract
 */
contract Vault is IVault, Ownable2Step, Rescuable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  address private immutable T_ASSET;
  IRateProviderRegistry public immutable RATE_PROVIDER_REGISTRY;

  EnumerableSet.AddressSet private _allowableAssets;

  IStrategyStorage public strategyStorage;
  address public redemption;

  constructor(address _creator, IRateProviderRegistry _rpr, address _tasset) Ownable(_creator) {
    RATE_PROVIDER_REGISTRY = _rpr;
    T_ASSET = _tasset;
  }

  /**
   * @notice This function is callable by active strategies. Allows withdrawal of asset from vault into strategy.
   * @param _asset asset to withdraw. Must be whitelisted and allowable
   * @param _amount amount to convert
   */
  function withdraw(address _asset, uint _amount) external {
    if (strategyStorage.isActiveStrategy(msg.sender) && strategyStorage.isAssetWhitelisted(msg.sender, _asset)) {
      IERC20(_asset).safeTransfer(msg.sender, _amount);
    } else {
      revert InvalidStrategy();
    }
  }

  /**
   * @notice Updates strategystorage address
   * @param _newStrategyStorage new strategyStorage address
   */
  function setStrategyStorage(IStrategyStorage _newStrategyStorage) external onlyOwner {
    emit StrategyStorageUpdated(address(_newStrategyStorage), address(strategyStorage));
    strategyStorage = _newStrategyStorage;
  }

  /**
   * @notice Updates redemption address
   * @param _newRedemption new redemption address
   * @dev approves/revokes new/old redemption contract to pull `underlying`
   */
  function setRedemption(address _newRedemption) external onlyOwner {
    if (_newRedemption == address(0)) revert InvalidAddress();
    emit RedemptionUpdated(_newRedemption, redemption);

    if (redemption != address(0)) {
      IERC20(getUnderlying()).approve(redemption, 0);
    }

    IERC20(getUnderlying()).approve(_newRedemption, type(uint).max);

    redemption = _newRedemption;
  }

  /**
   * @notice Returns the assets allowable for deposit
   */
  function getAllowableAssets() external view returns (address[] memory) {
    return _allowableAssets.values();
  }

  /**
   * @notice Returns true if an asset is allowable for deposit
   */
  function isAllowableAsset(address _asset) external view returns (bool) {
    if (_asset == address(0)) revert InvalidAddress();
    return _allowableAssets.contains(_asset);
  }

  /**
   * @notice Returns the number of assets allowable for deposit
   */
  function getAllowableAssetCount() external view returns (uint) {
    return _allowableAssets.length();
  }

  /**
   * @notice Returns the underlying asset of vault
   */
  function getUnderlying() public view returns (address) {
    return address(ITAsset(T_ASSET).getUnderlying());
  }

  /**
   * @notice Returns the TAsset of the vault
   */
  function getTAsset() public view returns (address) {
    return address(T_ASSET);
  }

  /**
   * @notice Add allowable ERC20 asset.
   * @param _asset asset to add
   * @dev Must be <= 18 decimals and must have a rate provider.
   */
  function addAllowableAsset(address _asset) external onlyOwner {
    if (IERC20Metadata(_asset).decimals() > 18) revert UnsupportedDecimals();
    RATE_PROVIDER_REGISTRY.checkHasRateProvider(_asset);

    bool success = _allowableAssets.add(_asset);
    if (!success) revert Failed();
    emit AllowableAssetAdded(_asset);
  }

  /**
   * @notice Remove allowable asset
   * @param _asset asset to remove
   */
  function removeAllowableAsset(address _asset) external onlyOwner {
    bool success = _allowableAssets.remove(_asset);
    if (!success) revert Failed();
    emit AllowableAssetRemoved(_asset);
  }

  ////////////////////// Inheritance overrides. Note: Sequence doesn't matter ////////////////////////

  function transferOwnership(address newOwner) public virtual override(Ownable2Step, Ownable) onlyOwner {
    super.transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal virtual override(Ownable2Step, Ownable) {
    super._transferOwnership(newOwner);
  }
}
