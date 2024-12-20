// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';

interface IFastlaneFee {
  function fee() external view returns (uint);

  function applyFee(uint _grossAmount) external view returns (uint _feeCharged);
}

/**
 * @notice Fastlane fee contract
 */
contract FastlaneFee is IFastlaneFee, Ownable2Step {
  uint constant PRECISION = 1e4;
  uint public fee = 200; // 2% in bips

  error MaxFeeExceeded();

  event FeeUpdated(uint _new, uint _old);

  constructor(address _owner) Ownable(_owner) {}

  /**
   * Apply fee on a `_grossAmount`
   * @param _grossAmount amount to levy fees on
   * @return _feeCharged fee charged on gross amount
   */
  function applyFee(uint _grossAmount) external view returns (uint _feeCharged) {
    unchecked {
      return (fee * _grossAmount) / PRECISION;
    }
  }

  /**
   * Set fees (max 5%)
   * @dev onlyOwner
   * @param _newFee new fee in bips
   */
  function setFee(uint _newFee) external onlyOwner {
    if (_newFee > 500) revert MaxFeeExceeded(); // max fee of 500 bips (5%)
    emit FeeUpdated(_newFee, fee);
    fee = _newFee;
  }
}
