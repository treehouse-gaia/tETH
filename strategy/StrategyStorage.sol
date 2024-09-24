// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

interface IStrategyStorage {
  struct StrategyParameters {
    bool isActive;
    EnumerableSet.Bytes32Set whitelistedActions;
    EnumerableSet.AddressSet whitelistedAssets;
  }

  error AlreadyExist();
  error DoesNotExist();

  event AssetWhitelisted(address _asset);
  event AssetUnwhitelisted(address _asset);
  event ActionWhitelisted(bytes4 _actionId);
  event ActionUnwhitelisted(bytes4 _actionId);
  event StrategyPaused(uint _strategyId);
  event StrategyUnpaused(uint _strategyId);
  event StrategyCreated(uint _index, address[] _allowedAssets, bytes4[] _allowedActions);
  event StrategyExecutorUpdated(address _newExecutor, address _oldExecutor);

  function getStrategyInfo(
    uint _strategyId
  )
    external
    view
    returns (
      address _strategyAddress,
      bool _isActive,
      bytes32[] memory _allowedActions,
      address[] memory _allowedAssets
    );

  function getStrategyCount() external view returns (uint _count);

  function isActiveStrategy(address _strategy) external view returns (bool _isActiveStrategy);

  function isAssetWhitelisted(address _strategy, address _asset) external view returns (bool _isAssetWhitelisted);

  function isActionWhitelisted(address _strategy, bytes4 _actionId) external view returns (bool _isActionWhitelisted);

  function getStrategyAddress(uint _strategyId) external view returns (address _strategyAddress);

  function strategyExecutor() external view returns (address);
}

/**
 * @notice Store created strategies and associated metadata
 */
contract StrategyStorage is IStrategyStorage, Ownable2Step {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  mapping(address strategy => StrategyParameters) private parameters;
  EnumerableSet.AddressSet private strategies;
  address public strategyExecutor;

  constructor(address _creator) Ownable(_creator) {}

  /**
   * @notice stores a created strategy and associated metadata
   * @param _strategy strategy address
   * @param _allowedActions list of assets allowed
   * @param _allowedAssets list of assets allowed
   * @return _strategyIndex strategy Id
   */
  function storeStrategy(
    address _strategy,
    bytes4[] calldata _allowedActions,
    address[] calldata _allowedAssets
  ) external onlyOwner returns (uint _strategyIndex) {
    if (strategies.add(_strategy) == false) revert AlreadyExist();
    _strategyIndex = strategies.length() - 1;

    bool success;
    for (uint i; i < _allowedActions.length; ++i) {
      success = parameters[_strategy].whitelistedActions.add(_allowedActions[i]);
      if (!success) revert AlreadyExist();
    }

    for (uint i; i < _allowedAssets.length; ++i) {
      success = parameters[_strategy].whitelistedAssets.add(_allowedAssets[i]);
      if (!success) revert AlreadyExist();
    }

    parameters[_strategy].isActive = true;

    emit StrategyCreated(_strategyIndex, _allowedAssets, _allowedActions);
  }

  /**
   * @notice whitelist actions for given strategy id
   * @param _strategyId strategy id
   * @param _whitelistedActions whitelisted action array
   */
  function whitelistActions(uint _strategyId, bytes4[] calldata _whitelistedActions) external onlyOwner {
    for (uint i; i < _whitelistedActions.length; ++i) {
      if (parameters[_safeGetStrategyAddress(_strategyId)].whitelistedActions.add(_whitelistedActions[i]) == false)
        revert AlreadyExist();

      emit ActionWhitelisted(_whitelistedActions[i]);
    }
  }

  /**
   * @notice un-whitelist actions for given strategy id
   * @param _strategyId strategy id
   * @param _unwhitelistedActions un-whitelisted action array
   */
  function unwhitelistActions(uint _strategyId, bytes4[] calldata _unwhitelistedActions) external onlyOwner {
    for (uint i; i < _unwhitelistedActions.length; ++i) {
      if (parameters[_safeGetStrategyAddress(_strategyId)].whitelistedActions.remove(_unwhitelistedActions[i]) == false)
        revert DoesNotExist();

      emit ActionUnwhitelisted(_unwhitelistedActions[i]);
    }
  }

  /**
   * @notice whitelist assets for given strategy id
   * @param _strategyId strategy id
   * @param _whitelistedAssets whitelisted asset array
   */
  function whitelistAssets(uint _strategyId, address[] calldata _whitelistedAssets) external onlyOwner {
    for (uint i; i < _whitelistedAssets.length; ++i) {
      if (parameters[_safeGetStrategyAddress(_strategyId)].whitelistedAssets.add(_whitelistedAssets[i]) == false)
        revert AlreadyExist();

      emit AssetWhitelisted(_whitelistedAssets[i]);
    }
  }

  /**
   * @notice un-whitelist assets for given strategy id
   * @param _strategyId strategy id
   * @param _unwhitelistedAssets un-whitelisted action array
   */
  function unwhitelistAssets(uint _strategyId, address[] calldata _unwhitelistedAssets) external onlyOwner {
    for (uint i; i < _unwhitelistedAssets.length; ++i) {
      if (parameters[_safeGetStrategyAddress(_strategyId)].whitelistedAssets.remove(_unwhitelistedAssets[i]) == false)
        revert DoesNotExist();

      emit AssetUnwhitelisted(_unwhitelistedAssets[i]);
    }
  }

  /**
   * @notice pause strategy
   * @param _strategyId strategy id to pause
   */
  function pauseStrategy(uint _strategyId) external onlyOwner {
    parameters[_safeGetStrategyAddress(_strategyId)].isActive = false;
    emit StrategyPaused(_strategyId);
  }

  /**
   * @notice unpause strategy
   * @param _strategyId strategy id to unpause
   */
  function unpauseStrategy(uint _strategyId) external onlyOwner {
    parameters[_safeGetStrategyAddress(_strategyId)].isActive = true;
    emit StrategyUnpaused(_strategyId);
  }

  /**
   * @notice get information about specified strategy
   * @param _strategyId strategy Id
   * @return _strategyAddress  address of strategy
   * @return _isActive is strategy active
   * @return _allowedActions list of allowed actions
   * @return _allowedAssets  list of allowed assets
   */
  function getStrategyInfo(
    uint _strategyId
  )
    external
    view
    returns (
      address _strategyAddress,
      bool _isActive,
      bytes32[] memory _allowedActions,
      address[] memory _allowedAssets
    )
  {
    _strategyAddress = _safeGetStrategyAddress(_strategyId);
    _isActive = parameters[_strategyAddress].isActive;
    _allowedActions = parameters[_strategyAddress].whitelistedActions.values();
    _allowedAssets = parameters[_strategyAddress].whitelistedAssets.values();
  }

  /**
   * @notice get address of specified strategy Id
   * @param _strategyId  strategy Id
   */
  function getStrategyAddress(uint _strategyId) external view returns (address _strategyAddress) {
    _strategyAddress = _safeGetStrategyAddress(_strategyId);
  }

  /**
   * @notice get strategy count
   * @return _count  number of strategies
   */
  function getStrategyCount() external view returns (uint _count) {
    _count = strategies.length();
  }

  /**
   * @notice get status of strategy
   * @param _strategy  strategy Id
   * @return _isActiveStrategy is strategy active
   */
  function isActiveStrategy(address _strategy) external view returns (bool _isActiveStrategy) {
    _isActiveStrategy = strategies.contains(_strategy) && parameters[_strategy].isActive;
  }

  /**
   * @notice get status of strategy
   * @param _strategy strategy Id
   * @param _token token that maybe whitelisted
   * @return _isAssetWhitelisted is asset whitelisted
   */
  function isAssetWhitelisted(address _strategy, address _token) external view returns (bool _isAssetWhitelisted) {
    _isAssetWhitelisted = strategies.contains(_strategy) && parameters[_strategy].whitelistedAssets.contains(_token);
  }

  /**
   * @notice get action whitelisted
   * @param _strategy strategy Id
   * @param _actionId action Id
   * @return _isActionWhitelisted is action whitelisted
   */
  function isActionWhitelisted(address _strategy, bytes4 _actionId) external view returns (bool _isActionWhitelisted) {
    _isActionWhitelisted = parameters[_strategy].whitelistedActions.contains(_actionId);
  }

  function _safeGetStrategyAddress(uint _strategyId) internal view returns (address _address) {
    if (_strategyId >= strategies.length()) revert DoesNotExist();
    _address = strategies.at(_strategyId);
  }

  /**
   * @notice set new strategy executor
   * @param _newExecutor set new executor
   */
  function setStrategyExecutor(address _newExecutor) external onlyOwner {
    emit StrategyExecutorUpdated(_newExecutor, strategyExecutor);
    strategyExecutor = _newExecutor;
  }
}
