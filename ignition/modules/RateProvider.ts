import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { CONSTANTS } from '../constants'

const RateProviderModule = buildModule(`RateProviderModule`, (m) => {
  const deployer = m.getAccount(0)
  const usdEthOracle = m.getParameter(`usdEthOracle`, CONSTANTS.CHAINLINK.USD_ETH_ORACLE)
  const stethEthOracle = m.getParameter(`stethEthOracle`, CONSTANTS.CHAINLINK.STETH_ETH_ORACLE)
  const weth = m.getParameter(`weth`, CONSTANTS.WETH)
  const steth = m.getParameter(`steth`, CONSTANTS.STETH)
  const wsteth = m.getParameter(`wsteth`, CONSTANTS.WSTETH)

  const usdEthRp = m.contract(`ChainlinkRateProvider`, [usdEthOracle], { id: usdEthOracle.name })
  const rpr = m.contract(`RateProviderRegistry`, [deployer, weth, usdEthRp])

  const stethRp = m.contract(`ChainlinkRateProvider`, [stethEthOracle], { id: stethEthOracle.name })
  const wstethRp = m.contract(`WstETHRateProvider`, [wsteth, stethRp])

  m.call(rpr, `update`, [steth, stethRp], { id: `stethRp` })
  m.call(rpr, `update`, [wsteth, wstethRp], { id: `wstethRp` })

  return { rpr, stethRp, wstethRp, usdEthRp }
})

export default RateProviderModule
