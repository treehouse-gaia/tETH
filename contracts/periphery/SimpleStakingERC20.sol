// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

// External dependencies
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { SafeERC20 } from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import { Ownable, Ownable2Step } from '@openzeppelin/contracts/access/Ownable2Step.sol';

interface ISimpleStakingERC20 {
  /// @notice Struct to hold the supported booleans
  /// @param deposit true if deposit is supported
  /// @param withdraw true if withdraw is supported
  struct Supported {
    bool deposit;
    bool withdraw;
  }

  /// @notice Error emitted when the amount is null
  error AMOUNT_NULL();

  /// @notice Error emitted when the address is null
  error ADDRESS_NULL();

  /// @notice Error emitted when the balance is insufficient
  error INSUFFICIENT_BALANCE();

  /// @notice Error emitted when the token is not allowed
  error TOKEN_NOT_ALLOWED(IERC20 token);

  /// @notice Event emitted when a token is added or removed
  /// @param token address of the token
  /// @param supported struct with deposit and withdraw booleans
  event SupportedToken(IERC20 indexed token, Supported supported);

  /// @notice Event emitted when a deposit is made
  /// @param token address of the token
  /// @param staker address of the staker
  /// @param amount amount of the deposit
  event Deposit(IERC20 indexed token, address indexed staker, uint256 amount);

  /// @notice Event emitted when a withdrawal is made
  /// @param token address of the token
  /// @param staker address of the staker
  /// @param amount amount of the withdrawal
  event Withdraw(IERC20 indexed token, address indexed staker, uint256 amount);

  /// @notice Method to deposit tokens
  /// @dev token are transferred from the sender, and the receiver is credited
  /// @param _token address of the token
  /// @param _amount amount to deposit
  /// @param _receiver address of the receiver
  function deposit(IERC20 _token, uint256 _amount, address _receiver) external;

  /// @notice Method to rescue tokens, only callable by the owner
  /// @dev difference between balance and internal balance is transferred to the owner
  /// @param _token address of the token
  function rescueERC20(IERC20 _token) external;

  /// @notice Method to add or remove a token
  /// @dev only callable by the owner
  /// @param _token address of the token
  /// @param _supported struct with deposit and withdraw booleans
  function supportToken(IERC20 _token, Supported calldata _supported) external;

  /// @notice Method to rescue tokens, only callable by the owner
  /// @dev token are transferred to the receiver and sender is credited
  /// @param _token address of the token
  /// @param _amount amount to withdraw
  /// @param _receiver address of the receiver
  function withdraw(IERC20 _token, uint256 _amount, address _receiver) external;
}

contract SimpleStakingERC20 is Ownable2Step, ReentrancyGuard, ISimpleStakingERC20 {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Mapping of supported tokens
  /// IERC20 address -> bool (true if supported)
  mapping(IERC20 => Supported) public supportedTokens;

  /// @notice Total staked balance for each token
  /// IERC20 address -> uint256 (total staked balance)
  mapping(IERC20 => uint256) public totalStakedBalance;

  /// @notice Staked balances for each user
  /// user address -> IERC20 address -> uint256 (staked balance)
  mapping(address => mapping(IERC20 => uint256)) public stakedBalances;

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  constructor(address _owner) Ownable(_owner) {}

  /*//////////////////////////////////////////////////////////////
                               RESTRICTED
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISimpleStakingERC20
  function supportToken(IERC20 _token, Supported calldata _supported) external onlyOwner {
    if (address(_token) == address(0)) revert ADDRESS_NULL();

    supportedTokens[_token] = _supported;

    emit SupportedToken(_token, _supported);
  }

  /// @inheritdoc ISimpleStakingERC20
  function rescueERC20(IERC20 _token) external onlyOwner {
    _token.safeTransfer(owner(), _token.balanceOf(address(this)) - totalStakedBalance[_token]);
  }

  /*//////////////////////////////////////////////////////////////
                                 PUBLIC
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISimpleStakingERC20
  function deposit(IERC20 _token, uint256 _amount, address _receiver) external nonReentrant {
    if (_amount == 0) revert AMOUNT_NULL();
    if (_receiver == address(0)) revert ADDRESS_NULL();
    if (!supportedTokens[_token].deposit) revert TOKEN_NOT_ALLOWED(_token);

    uint256 bal = _token.balanceOf(address(this));
    _token.safeTransferFrom(msg.sender, address(this), _amount);
    _amount = _token.balanceOf(address(this)) - bal; // To handle deflationary tokens

    totalStakedBalance[_token] += _amount;

    unchecked {
      stakedBalances[_receiver][_token] += _amount;
    }

    emit Deposit(_token, _receiver, _amount);
  }

  /// @inheritdoc ISimpleStakingERC20
  function withdraw(IERC20 _token, uint256 _amount, address _receiver) external nonReentrant {
    if (_amount == 0) revert AMOUNT_NULL();
    if (stakedBalances[msg.sender][_token] < _amount) revert INSUFFICIENT_BALANCE();
    if (_receiver == address(0)) revert ADDRESS_NULL();
    if (!supportedTokens[_token].withdraw) revert TOKEN_NOT_ALLOWED(_token);

    unchecked {
      totalStakedBalance[_token] -= _amount;
      stakedBalances[msg.sender][_token] -= _amount;
    }

    _token.safeTransfer(_receiver, _amount);

    emit Withdraw(_token, msg.sender, _amount);
  }
}
