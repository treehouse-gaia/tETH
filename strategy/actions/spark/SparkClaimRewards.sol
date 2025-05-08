// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../../libs/TokenUtils.sol';
import '../ActionBase.sol';
import './helpers/SparkHelper.sol';
import '../../../interfaces/aaveV3/IRewardsController.sol';

/// @title Claims single reward type specified by reward for the list of assets. Rewards are received by to address.
contract SparkClaimRewards is ActionBase, SparkHelper {
  using TokenUtils for address;
  string constant NAME = 'SparkClaimRewards';

  struct Params {
    uint256 amount;
    address reward;
    address[] assets;
  }

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    params.amount = _parseParamUint(params.amount, _paramMapping[0], _returnValues);

    (uint256 amountReceived, bytes memory logData) = _claimRewards(params);

    emit ActionEvent(NAME, logData);
    return bytes32(amountReceived);
  }

  //////////////////////////// ACTION LOGIC ////////////////////////////
  function _claimRewards(Params memory _params) internal returns (uint256 amountReceived, bytes memory) {
    IRewardsController rewardsController = IRewardsController(SPARK_REWARDS_CONTROLLER_ADDRESS);

    amountReceived = rewardsController.claimRewards(_params.assets, _params.amount, address(this), _params.reward);

    bytes memory logData = abi.encode(_params, amountReceived);
    return (amountReceived, logData);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory params) {
    params = abi.decode(_callData, (Params));
  }
}
