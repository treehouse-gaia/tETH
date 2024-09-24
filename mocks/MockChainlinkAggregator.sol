// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import '@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

contract MockChainlinkAggregator {
  AggregatorV3Interface public immutable pricefeed;
  uint80 _rid;
  int _ans;
  uint _startedAt;
  uint _updatedAt;
  uint80 _answeredInRound;

  constructor(AggregatorV3Interface feed) {
    pricefeed = feed;
    (_rid, _ans, _startedAt, _updatedAt, _answeredInRound) = pricefeed.latestRoundData();
  }

  function setAnswer(int _newAns) external {
    _ans = _newAns;
  }

  function latestRoundData()
    public
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (_rid, _ans, _startedAt, _updatedAt, _answeredInRound);
  }

  /**
   * @notice median from the most recent report
   */
  function latestAnswer() public view returns (int256) {
    return _ans;
  }

  /**
   * @notice timestamp of block in which last report was transmitted
   */
  function latestTimestamp() public view returns (uint256) {
    return _updatedAt;
  }

  /**
   * @notice Aggregator round (NOT OCR round) in which last report was transmitted
   */
  function latestRound() public view returns (uint256) {
    return _rid;
  }

  /**
   * @notice median of report from given aggregator round (NOT OCR round)

   */
  function getAnswer(uint256) public view returns (int256) {
    return _ans;
  }

  /**
   * @notice timestamp of block in which report from given aggregator round was transmitted
   */
  function getTimestamp(uint256) public view returns (uint256) {
    return _updatedAt;
  }
}
