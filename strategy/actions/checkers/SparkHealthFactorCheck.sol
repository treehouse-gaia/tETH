// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../ActionBase.sol';
import '../../../interfaces/aaveV3/IPoolV3.sol';
import '../spark/helpers/SparkHelper.sol';
import { IProtocolPoolController } from '../../controllers/ProtocolPoolController.sol';

contract SparkHealthFactorCheck is ActionBase, SparkHelper {
  error BadAfterCheck(uint currHf, uint targetHf);
  address public immutable PROTOCOL_CONTROLLER;
  string constant NAME = 'SparkHealthFactorCheck';

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  struct Params {
    uint targetHealthFactor;
    uint16 poolId;
  }

  constructor(address _protocolRegisterAddress) {
    PROTOCOL_CONTROLLER = _protocolRegisterAddress;
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    uint targetHf = _parseParamUint(params.targetHealthFactor, _paramMapping[0], _returnValues);
    address _lendingPool = IProtocolPoolController(PROTOCOL_CONTROLLER).getPoolAddress(PROTOCOL_ID, params.poolId);
    (, , , , , uint currHf) = IPoolV3(_lendingPool).getUserAccountData(address(this));

    if (currHf < targetHf) {
      revert BadAfterCheck(currHf, targetHf);
    }

    emit ActionEvent(NAME, abi.encode(currHf, targetHf));
    return bytes32(currHf);
  }

  function parseInputs(bytes memory _callData) public pure returns (Params memory inputData) {
    inputData = abi.decode(_callData, (Params));
  }
}
