// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

import '../libs/Rescuable.sol';

contract MockRescuable is Rescuable {
  constructor() Ownable(msg.sender) {}
}
