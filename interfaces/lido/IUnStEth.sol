// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

/// @dev https://docs.lido.fi/contracts/withdrawal-queue-erc721
/// @dev https://etherscan.io/address/0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1
interface IUnStEth {
  /// @notice output format struct for `_getWithdrawalStatus()` method
  struct WithdrawalRequestStatus {
    /// @notice stETH token amount that was locked on withdrawal queue for this request
    uint256 amountOfStETH;
    /// @notice amount of stETH shares locked on withdrawal queue for this request
    uint256 amountOfShares;
    /// @notice address that can claim or transfer this request
    address owner;
    /// @notice timestamp of when the request was created, in seconds
    uint256 timestamp;
    /// @notice true, if request is finalized
    bool isFinalized;
    /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
    bool isClaimed;
  }

  /// @notice Returns stETH address
  /// @return _stETH stETH address
  function STETH() external view returns (address _stETH);

  /// @notice Returns wstETH address
  /// @return _wstETH wstETH address
  function WSTETH() external view returns (address _wstETH);

  /// @notice Request the batch of stETH for withdrawal. Approvals for the passed amounts should be done before.
  /// @param _amounts an array of stETH amount values.
  ///  The standalone withdrawal request will be created for each item in the passed list.
  /// @param _owner address that will be able to manage the created requests.
  ///  If `address(0)` is passed, `msg.sender` will be used as owner.
  /// @return requestIds an array of the created withdrawal request ids
  function requestWithdrawals(
    uint256[] calldata _amounts,
    address _owner
  ) external returns (uint256[] memory requestIds);

  /// @notice Request the batch of wstETH for withdrawal. Approvals for the passed amounts should be done before.
  /// @param _amounts an array of wstETH amount values.
  ///  The standalone withdrawal request will be created for each item in the passed list.
  /// @param _owner address that will be able to manage the created requests.
  ///  If `address(0)` is passed, `msg.sender` will be used as an owner.
  /// @return requestIds an array of the created withdrawal request ids
  function requestWithdrawalsWstETH(
    uint256[] calldata _amounts,
    address _owner
  ) external returns (uint256[] memory requestIds);

  /// @notice Returns amount of ether available for claim for each provided request id
  /// @param _requestIds array of request ids
  /// @param _hints checkpoint hints. can be found with `findCheckpointHints(_requestIds, 1, getLastCheckpointIndex())`
  /// @return claimableEthValues amount of claimable ether for each request, amount is equal to 0 if request
  ///  is not finalized or already claimed
  function getClaimableEther(
    uint256[] calldata _requestIds,
    uint256[] calldata _hints
  ) external view returns (uint256[] memory claimableEthValues);

  /// @notice Returns status for requests with provided ids
  /// @param _requestIds array of withdrawal request ids
  function getWithdrawalStatus(
    uint256[] calldata _requestIds
  ) external view returns (WithdrawalRequestStatus[] memory statuses);

  /// @notice Claim a batch of withdrawal requests if they are finalized sending locked ether to the owner
  /// @param _requestIds array of request ids to claim
  /// @param _hints checkpoint hint for each id. Can be obtained with `findCheckpointHints()`
  /// @dev
  ///  Reverts if requestIds and hints arrays length differs
  ///  Reverts if any requestId or hint in arguments are not valid
  ///  Reverts if any request is not finalized or already claimed
  ///  Reverts if msg sender is not an owner of the requests
  function claimWithdrawals(uint256[] calldata _requestIds, uint256[] calldata _hints) external;

  /// @notice Claim one`_requestId` request once finalized sending locked ether to the owner
  /// @param _requestId request id to claim
  /// @dev use unbounded loop to find a hint, which can lead to OOG
  /// @dev
  ///  Reverts if requestId or hint are not valid
  ///  Reverts if request is not finalized or already claimed
  ///  Reverts if msg sender is not an owner of request
  function claimWithdrawal(uint256 _requestId) external;

  /// @notice Finds the list of hints for the given `_requestIds` searching among the checkpoints with indices
  ///  in the range  `[_firstIndex, _lastIndex]`.
  ///  NB! Array of request ids should be sorted
  ///  NB! `_firstIndex` should be greater than 0, because checkpoint list is 1-based array
  ///  Usage: findCheckpointHints(_requestIds, 1, getLastCheckpointIndex())
  /// @param _requestIds ids of the requests sorted in the ascending order to get hints for
  /// @param _firstIndex left boundary of the search range. Should be greater than 0
  /// @param _lastIndex right boundary of the search range. Should be less than or equal to getLastCheckpointIndex()
  /// @return hintIds array of hints used to find required checkpoint for the request
  function findCheckpointHints(
    uint256[] calldata _requestIds,
    uint256 _firstIndex,
    uint256 _lastIndex
  ) external view returns (uint256[] memory hintIds);
}
