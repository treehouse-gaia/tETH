import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import RateProviderModule from './RateProvider'
import TAssetModule from './TAsset'

const VaultModule = buildModule(`VaultModule`, (m) => {
  const deployer = m.getAccount(0)
  const { rpr } = m.useModule(RateProviderModule)
  const { tasset } = m.useModule(TAssetModule)

  const vault = m.contract(`Vault`, [deployer, rpr, tasset])

  return { vault }
})

export default VaultModule
