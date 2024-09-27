import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import RateProviderModule from './RateProvider'
import ActionModule from './Action'

const StrategyModule = buildModule(`StrategyModule`, (m) => {
  const deployer = m.getAccount(0)
  m.useModule(RateProviderModule)
  const { actionRegistry } = m.useModule(ActionModule)

  const actionExecutor = m.contract(`ActionExecutor`, [actionRegistry])
  const strategyStorage = m.contract(`StrategyStorage`, [deployer])
  const strategyExecutor = m.contract(`StrategyExecutor`, [deployer, actionExecutor, strategyStorage])

  return { strategyStorage, strategyExecutor, actionExecutor }
})

export default StrategyModule
