// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '@openzeppelin/contracts/access/Ownable2Step.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

interface IRescuable {
  function rescueETH(address to) external;

  function rescueERC20(IERC20 tokenContract, address to, uint amount) external;
}

/**
 * This contract allows rescuing from the vault into a hardcoded funds receiver address
 */
contract VaultRescuer is Ownable2Step {
  using SafeERC20 for IERC20;

  error TimelockInEffect();
  error WithdrawFailed();

  event FundsRescued(address token, uint amount);
  event FundsWithdrawn(address token, uint amount);

  address public immutable FUNDS_RECEIVER;
  address public immutable VAULT;
  uint public immutable WAIT_TIME = 5 days;
  address public constant NATIVE = address(0);

  uint public lastRescuedTimestamp;

  constructor(address initialOwner, address vault, address fundsReceiver) Ownable(initialOwner) {
    FUNDS_RECEIVER = fundsReceiver;
    VAULT = vault;
  }

  /** Rescue ERC20 from vault */
  function rescueERC20(IERC20 tokenContract, uint amount) external onlyOwner {
    if (amount == 0) {
      amount = IERC20(tokenContract).balanceOf(VAULT);
      if (amount == 0) revert WithdrawFailed();
    }

    IRescuable(VAULT).rescueERC20(tokenContract, address(this), amount);
    lastRescuedTimestamp = block.timestamp;

    emit FundsRescued(address(tokenContract), amount);
  }

  /** Rescue native asset from vault */
  function rescueNative() external onlyOwner {
    uint balance = address(this).balance;
    IRescuable(VAULT).rescueETH(address(this));
    balance = address(this).balance - balance;

    if (balance == 0) revert WithdrawFailed();

    lastRescuedTimestamp = block.timestamp;

    emit FundsRescued(NATIVE, balance);
  }

  /**
   * Allows owner to withdraw funds to `FUNDS_RECEIVER` after `WAIT_TIME` has passed, since the rescue
   */
  function withdrawFunds(IERC20 tokenContract) external onlyOwner {
    if (block.timestamp < lastRescuedTimestamp + WAIT_TIME) revert TimelockInEffect();

    uint balance;

    if (address(tokenContract) == NATIVE) {
      balance = address(this).balance;
      (bool success, ) = address(FUNDS_RECEIVER).call{ value: balance }('');
      if (!success) revert WithdrawFailed();
    } else {
      balance = tokenContract.balanceOf(address(this));
      tokenContract.safeTransfer(FUNDS_RECEIVER, balance);
    }

    emit FundsWithdrawn(address(tokenContract), balance);
  }

  receive() external payable {}
}
