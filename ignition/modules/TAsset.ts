import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { CONSTANTS } from '../constants'

const TAssetModule = buildModule(`TAssetModule`, (m) => {
  const deployer = m.getAccount(0)
  const underlyingToken = m.getParameter(`underlyingToken`, CONSTANTS.WSTETH)
  const tAssetName = m.getParameter(`tAssetName`, `Treehouse ETH`) //TODO
  const tAssetSymbol = m.getParameter(`tAssetSymbol`, `tETH`) //TODO

  const iau = m.contract(`InternalAccountingUnit`, [deployer, underlyingToken])
  const tasset = m.contract(`TAsset`, [deployer, iau, tAssetName, tAssetSymbol])

  return {
    iau,
    tasset
  }
})

export default TAssetModule
