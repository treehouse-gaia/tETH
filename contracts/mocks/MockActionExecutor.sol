// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;

contract MockActionExecutor {
  event MockActionExecutorTriggered();

  fallback(bytes calldata) external returns (bytes memory) {
    emit MockActionExecutorTriggered();

    return '0x';
  }
}
