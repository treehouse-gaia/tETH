import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import VaultModule from './Vault'
import StrategyModule from './Strategy'
import ActionModule from './Action'

const PortfolioManagementModule = buildModule(`PortfolioManagement`, (m) => {
  const deployer = m.getAccount(0)
  const { vault } = m.useModule(VaultModule)
  const { strategyExecutor, strategyStorage } = m.useModule(StrategyModule)
  //eslint-disable-next-line
  const { actionRegistry, ...actions } = m.useModule(ActionModule)

  // set Vault's strategyStorage
  m.call(vault, `setStrategyStorage`, [strategyStorage])

  // create and store strategy
  const strategy = m.contract(`Strategy`, [deployer, strategyExecutor, vault])
  m.call(strategyStorage, `storeStrategy`, [strategy, [], []])

  return { strategyExecutor, strategyStorage, vault, strategy }
})

export default PortfolioManagementModule
