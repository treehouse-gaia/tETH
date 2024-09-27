// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../ActionBase.sol';
import '../../../interfaces/aaveV3/IPoolV3.sol';
import '../aaveV3/helpers/MainnetAaveV3Addresses.sol';

contract AaveV3HealthFactorCheck is ActionBase, MainnetAaveV3Addresses {
  error BadAfterCheck(uint currHf, uint targetHf);
  string constant NAME = 'AaveV3HealthFactorCheck';

  /// @inheritdoc ActionBase
  function getId() public pure override returns (bytes4) {
    return bytes4(keccak256(abi.encodePacked(NAME)));
  }

  struct Params {
    uint targetHealthFactor;
  }

  /// @inheritdoc ActionBase
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual override returns (bytes32) {
    Params memory params = parseInputs(_callData);
    uint targetHf = _parseParamUint(params.targetHealthFactor, _paramMapping[0], _returnValues);

    (, , , , , uint currHf) = IPoolV3(LENDING_POOL).getUserAccountData(address(this));

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
