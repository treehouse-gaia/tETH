// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

interface IActionBase {
  function getId() external pure returns (bytes4);
}

/// @title Implements Action interface and common helpers for passing inputs
abstract contract ActionBase is IActionBase {
  event ActionEvent(string indexed logName, bytes data);

  error Failed();
  //Wrong return index value
  error ReturnIndexValueError();

  /// @dev Return params index range [1, 127]
  uint8 public constant RETURN_MIN_INDEX_VALUE = 1;
  uint8 public constant RETURN_MAX_INDEX_VALUE = 127;

  /// @dev If the input value should not be replaced
  uint8 public constant NO_PARAM_MAPPING = 0;

  /// @notice Parses inputs and runs the implemented action through a user wallet
  /// @dev Is called by the ActionExecutor chaining actions together
  /// @param _callData Array of input values each value encoded as bytes
  /// @param _paramMapping Array that specifies how return and subscribed values are mapped in input
  /// @param _returnValues Returns values from actions before, which can be injected in inputs
  /// @return Returns a bytes32 value through user wallet, each actions implements what that value is
  function executeAction(
    bytes calldata _callData,
    uint8[] memory _paramMapping,
    bytes32[] memory _returnValues
  ) public payable virtual returns (bytes32);

  /// @notice Returns the id of action - first 4 bytes of keccak256 of contract name
  function getId() public pure virtual returns (bytes4);

  //////////////////////////// HELPER METHODS ////////////////////////////

  /// @notice Given an uint input, injects return/sub values if specified
  /// @param _param The original input value
  /// @param _mapType Indicated the type of the input in paramMapping
  /// @param _returnValues Array of subscription data we can replace the input value with
  function _parseParamUint(uint _param, uint8 _mapType, bytes32[] memory _returnValues) internal pure returns (uint) {
    if (isReplaceable(_mapType)) {
      _param = uint(_returnValues[getReturnIndex(_mapType)]);
    }

    return _param;
  }

  /// @notice Given an addr input, injects return/sub values if specified
  /// @param _param The original input value
  /// @param _mapType Indicated the type of the input in paramMapping
  /// @param _returnValues Array of subscription data we can replace the input value with
  function _parseParamAddr(
    address _param,
    uint8 _mapType,
    bytes32[] memory _returnValues
  ) internal pure returns (address) {
    if (isReplaceable(_mapType)) {
      _param = address(bytes20((_returnValues[getReturnIndex(_mapType)])));
    }

    return _param;
  }

  /// @notice Given an bytes32 input, injects return/sub values if specified
  /// @param _param The original input value
  /// @param _mapType Indicated the type of the input in paramMapping
  /// @param _returnValues Array of subscription data we can replace the input value with
  function _parseParamBytes32(
    bytes32 _param,
    uint8 _mapType,
    bytes32[] memory _returnValues
  ) internal pure returns (bytes32) {
    if (isReplaceable(_mapType)) {
      _param = (_returnValues[getReturnIndex(_mapType)]);
    }

    return _param;
  }

  /// @notice Checks if the paramMapping value indicated that we need to inject values
  /// @param _type Indicated the type of the input
  function isReplaceable(uint8 _type) internal pure returns (bool) {
    return _type != NO_PARAM_MAPPING;
  }

  /// @notice Checks if the paramMapping value is in the return value range
  /// @param _type Indicated the type of the input
  function isReturnInjection(uint8 _type) internal pure returns (bool) {
    return (_type >= RETURN_MIN_INDEX_VALUE) && (_type <= RETURN_MAX_INDEX_VALUE);
  }

  /// @notice Transforms the paramMapping value to the index in return array value
  /// @param _type Indicated the type of the input
  function getReturnIndex(uint8 _type) internal pure returns (uint8) {
    if (!(isReturnInjection(_type))) {
      revert ReturnIndexValueError();
    }

    return (_type - RETURN_MIN_INDEX_VALUE);
  }
}
