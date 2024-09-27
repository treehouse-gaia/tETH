import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import RateProviderModule from './RateProvider'
import PortfolioManagementModule from './PortfolioManagement'
import { CONSTANTS } from '../constants'
import ProtocolPhaseTwo from './ProtocolPhaseTwo'

const PnlModule = buildModule(`PnlModule`, (m) => {
  const deployer = m.getAccount(0)
  const { rpr } = m.useModule(RateProviderModule)
  const { iau, vault, treehouseAccounting } = m.useModule(ProtocolPhaseTwo)
  const { strategy } = m.useModule(PortfolioManagementModule)
  const pnlDeviation = m.getParameter(`pnlDeviation`, 200)
  const weth = m.getParameter(`weth`, CONSTANTS.WETH)
  const steth = m.getParameter(`steth`, CONSTANTS.STETH)
  const wsteth = m.getParameter(`wsteth`, CONSTANTS.WSTETH)
  const unsteth = m.getParameter(`unsteth`, CONSTANTS.UNSTETH)
  const aaveV3LendingPool = m.getParameter(`aaveV3LendingPool`, CONSTANTS.AAVE_V3_LENDING_POOL)

  const navHelper = m.contract(`NavHelper`, [steth, unsteth, aaveV3LendingPool, rpr, iau, vault])
  const pnlAccountingHelper = m.contract(`PnlAccountingHelper`, [
    deployer,
    weth,
    wsteth,
    navHelper,
    strategy,
    treehouseAccounting,
    pnlDeviation
  ])

  // set PnlAccountingHelper as executor of TreehouseAccounting
  m.call(treehouseAccounting, `updateExecutor`, [pnlAccountingHelper])
  return { navHelper, pnlAccountingHelper }
})

export default PnlModule
