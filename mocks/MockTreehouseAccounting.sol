// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import { ITreehouseAccounting } from '../TreehouseAccounting.sol';

contract MockTreehouseAccounting is ITreehouseAccounting {
  uint16 _fee;
  MarkType marktype;
  uint amountLessFee;
  uint feeLevied;

  function mark(MarkType _type, uint _amountLessFee, uint fee_) external {
    marktype = _type;
    amountLessFee = _amountLessFee;
    feeLevied = fee_;
  }

  function setFee(uint16 _param) external {
    _fee = _param;
  }

  function fee() external view returns (uint16) {
    return _fee;
  }
}
