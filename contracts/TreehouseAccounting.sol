// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC4626.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import { IInternalAccountingUnit } from './InternalAccountingUnit.sol';

interface ITreehouseAccounting {
  error Unauthorized();
  error UnknownMarkType();

  event ExecutorUpdated(address indexed _new, address indexed _old);
  event TreasuryUpdated(address indexed _new, address indexed _old);
  event Marked(MarkType _type, uint _amount, uint _fees);
  event FeeUpdated(uint16 _newFee, uint16 _oldFee);

  enum MarkType {
    BURN,
    MINT
  }

  function mark(MarkType _type, uint _amount, uint _fee) external;

  function fee() external view returns (uint16);
}

/**
 * @notice Accounting Module that mints/burns IAU from TAsset
 */
contract TreehouseAccounting is ITreehouseAccounting, Ownable2Step {
  using SafeERC20 for IERC20;
  uint16 constant PRECISION = 1e4;

  address public immutable IAU;
  address public immutable TASSET;
  address public treasury;
  address public executor;
  uint16 public fee; // in bips

  constructor(
    address _creator,
    address _iau,
    address tasset,
    address _treasury,
    address _executor,
    uint16 _fee
  ) Ownable(_creator) {
    IAU = _iau;
    TASSET = tasset;
    treasury = _treasury;
    executor = _executor;
    fee = _fee;

    IERC20(IAU).approve(address(TASSET), type(uint).max);
  }

  modifier onlyOwnerOrExecutor() {
    if (executor != msg.sender && msg.sender != owner()) revert Unauthorized();
    _;
  }

  /**
   * @notice mints or burns IAU
   * @param _type MarkType - MINT or BURN
   * @param _amountLessFee - amount to mint less fee
   * @param _fee - protocol fee. Fees are not levied on burns
   */
  function mark(MarkType _type, uint _amountLessFee, uint _fee) external onlyOwnerOrExecutor {
    if (_type == MarkType.MINT) {
      IInternalAccountingUnit(IAU).mintTo(address(this), _fee);
      IERC4626(TASSET).deposit(_fee, treasury);
      IInternalAccountingUnit(IAU).mintTo(TASSET, _amountLessFee);
    } else if (_type == MarkType.BURN) {
      IInternalAccountingUnit(IAU).burnFrom(TASSET, _amountLessFee);
    } else {
      revert UnknownMarkType();
    }

    emit Marked(_type, _amountLessFee, _fee);
  }

  /**
   * @notice Set the accounting executor addresss
   * @param _newExecutor new executor address
   */
  function updateExecutor(address _newExecutor) external onlyOwner {
    emit ExecutorUpdated(_newExecutor, executor);
    executor = _newExecutor;
  }

  /**
   * @notice Set the treasury address
   * @param _newTreasury new treasury address
   */
  function updateTreasury(address _newTreasury) external onlyOwner {
    emit TreasuryUpdated(_newTreasury, treasury);
    treasury = _newTreasury;
  }

  /**
   * @notice Set the protocol fee
   * @param _newFee new fee in bips
   */
  function setFee(uint16 _newFee) external onlyOwner {
    if (_newFee > PRECISION) revert('max_fee');
    emit FeeUpdated(_newFee, fee);
    fee = _newFee;
  }
}
