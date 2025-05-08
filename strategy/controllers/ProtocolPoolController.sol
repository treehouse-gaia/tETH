// SPDX-License-Identifier: MIT
pragma solidity =0.8.24;
import '@openzeppelin/contracts/access/Ownable2Step.sol';

interface IProtocolPoolController {
  function getPoolAddress(uint protocolId, uint lendingPoolId) external view returns (address pool);

  function getDataProviderAddress(uint protocolId, uint lendingPoolId) external view returns (address dataprovider);
}

/**
 * Registry of immutable address for AaveV3-like protocols.
 * Addresses are assumed to be immutable and cannot be changed once added.
 */
contract ProtocolPoolController is IProtocolPoolController, Ownable2Step {
  //error
  error ProtocolIdNotDefined(uint protocolId);
  error PoolExist(address poolAddress);

  //event
  event PoolAddressAdded();
  event ProtocolAdded();

  struct ProtocolInfo {
    address lendingPool;
    address dataProvider;
  }
  mapping(uint protocolId => ProtocolInfo[]) private _protocolInfo;
  mapping(uint protocolId => string protocolName) private _protocolNames;
  uint public protocolCounter;

  constructor() Ownable(msg.sender) {}

  /**
   * add protocol name
   * @param protocolName protocol name
   */
  function addProtocol(string memory protocolName) external onlyOwner {
    _protocolNames[protocolCounter] = protocolName;
    protocolCounter++;
    emit ProtocolAdded();
  }

  /**
   * add pool address to the protocol
   * @param protocolId protocol id
   * @param lendingPoolAddress pool address
   * @param dataProviderAddress data provider address
   */
  function addPool(uint protocolId, address lendingPoolAddress, address dataProviderAddress) external onlyOwner {
    // check if the protocolId is valid
    if (protocolId >= protocolCounter) revert ProtocolIdNotDefined(protocolId);
    // check if the pool address is already exist
    uint _poolLength = _protocolInfo[protocolId].length;
    for (uint i; i < _poolLength; ++i) {
      if (_protocolInfo[protocolId][i].lendingPool == lendingPoolAddress) revert PoolExist(lendingPoolAddress);
    }
    // add the pool address to the protocol
    _protocolInfo[protocolId].push(ProtocolInfo(lendingPoolAddress, dataProviderAddress));
    emit PoolAddressAdded();
  }

  /**
   * get the pool address
   * @param protocolId protocol id
   * @param lendingPoolId pool id (position in array)
   * @return pool pool address
   */
  function getPoolAddress(uint protocolId, uint lendingPoolId) external view returns (address pool) {
    pool = _protocolInfo[protocolId][lendingPoolId].lendingPool;
  }

  /**
   * get the data provider address
   * @param protocolId protocol id
   * @param lendingPoolId pool id (position in array)
   * @return dataprovider data provider address
   */
  function getDataProviderAddress(uint protocolId, uint lendingPoolId) external view returns (address dataprovider) {
    dataprovider = _protocolInfo[protocolId][lendingPoolId].dataProvider;
  }

  /**
   * get the protocol name and info
   * @param protocolId protocol id
   * @param lendingPoolId pool id (position in array)
   * @return name protocol name
   * @return pool struct containing lending pool and data provider address
   */
  function getProtocolInfo(
    uint protocolId,
    uint lendingPoolId
  ) external view returns (string memory name, ProtocolInfo memory pool) {
    name = _protocolNames[protocolId];
    pool = _protocolInfo[protocolId][lendingPoolId];
  }

  /**
   * get the number of instances of protocol
   * @param protocolId protocol id
   * @return instances number of protocol instances
   */
  function getProtocolInfoLength(uint protocolId) external view returns (uint instances) {
    return _protocolInfo[protocolId].length;
  }
}
