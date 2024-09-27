import { ethers, ignition } from 'hardhat'
import { ERC20, NavHelper, PnlAccountingHelper, StrategyExecutor, StrategyStorage } from '../typechain-types'
import { eth } from './utils'
import PortfolioManagementModule from '../ignition/modules/PortfolioManagement'
import { CONSTANTS } from '../ignition/constants'
import PnlModule from '../ignition/modules/Pnl'
import ActionModule from '../ignition/modules/Action'

async function main() {
  const encoder = new ethers.AbiCoder()
  const [deployer] = await ethers.getSigners()

  const c_weth = await ethers.getContractAt(`ERC20`, CONSTANTS.WETH)
  const c_steth = await ethers.getContractAt(`ERC20`, CONSTANTS.STETH)
  const c_wsteth = await ethers.getContractAt(`ERC20`, CONSTANTS.WSTETH)
  const c_aaveV3Pool = await ethers.getContractAt(`IPoolV3`, `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`)
  const c_a_wsteth = await ethers.getContractAt(`ERC20`, `0x0B925eD163218f6662a35e0f0371Ac234f9E9371`)
  const c_vd_weth = await ethers.getContractAt(`ERC20`, `0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE`)

  const { navHelper, pnlAccountingHelper } = await ignition.deploy(PnlModule)
  const _navHelper = navHelper as unknown as NavHelper
  const _pnlAccountingHelper = pnlAccountingHelper as unknown as PnlAccountingHelper

  const { strategyExecutor, strategyStorage } = await ignition.deploy(PortfolioManagementModule)
  const { vaultPull, lidoWrap, aaveV3Supply, aaveV3HealthFactorCheck, aaveV3Borrow } =
    await ignition.deploy(ActionModule)
  const _strategyExecutor = strategyExecutor as unknown as StrategyExecutor
  const _strategyStorage = strategyStorage as unknown as StrategyStorage
  const _strategy = await ethers.getContractAt(`Strategy`, await _strategyStorage.getStrategyAddress(0))
  const stratAddress = await _strategy.getAddress()
  const printBalanceOfStratAddress = printBalanceOf(stratAddress)

  const printBal = async () => {
    await printBalanceOfStratAddress(c_wsteth)
    await printBalanceOfStratAddress(c_steth)
    await printBalanceOfStratAddress(c_a_wsteth)
    await printBalanceOfStratAddress(c_vd_weth)
    await printBalanceOfStratAddress(c_weth)
  }

  // update strat executor
  await _strategyExecutor.updateExecutor(deployer, true)

  // aave vars
  const AAVE_ASSET_ID = { WETH: 0, WSTETH: 1 }

  const STRATEGY_ID = 0

  const vp = await (await ethers.getContractAt(`IActionBase`, vaultPull)).getId()
  const lw = await (await ethers.getContractAt(`IActionBase`, lidoWrap)).getId()
  const av3s = await (await ethers.getContractAt(`IActionBase`, aaveV3Supply)).getId()
  const av3hfCheck = await (await ethers.getContractAt(`IActionBase`, aaveV3HealthFactorCheck)).getId()
  const av3borrow = await (await ethers.getContractAt(`IActionBase`, aaveV3Borrow)).getId()

  const actionIdArr = [vp, lw, av3s, av3hfCheck]

  //whitelist if not whitelisted
  if (!(await _strategyStorage.isAssetWhitelisted(stratAddress, c_wsteth))) {
    console.log(`whitelisting assets`)
    await _strategyStorage.whitelistAssets(STRATEGY_ID, [c_wsteth])
  }

  if (!(await _strategyStorage.isActionWhitelisted(stratAddress, actionIdArr[0]))) {
    console.log(`whitelisting actions`)
    await _strategyStorage.whitelistActions(STRATEGY_ID, [vp, lw, av3s, av3borrow, av3hfCheck])
  }

  console.log(`\n>> Before <<`)
  console.log(
    `health Factor`,
    (+ethers.formatEther((await c_aaveV3Pool.getUserAccountData(stratAddress)).healthFactor)).toFixed(4)
  )
  await printBal()
  console.log(`protocol NAV`, ethers.formatEther(await _navHelper.getProtocolIau()))
  console.log(
    `pm NAV`,
    ethers.formatEther((await _navHelper.getVaultNav()) + (await _pnlAccountingHelper.getNavOfStrategy([])))
  )

  await _strategyExecutor.executeOnStrategy(
    STRATEGY_ID,
    [vp, av3s, av3borrow, av3hfCheck],
    [
      encoder.encode([`address`, `uint`], [await c_wsteth.getAddress(), eth(1)]), // vaultPull
      encoder.encode([`uint`, `uint16`], [0, AAVE_ASSET_ID.WSTETH]), // wstETH aaveV3 supply
      encoder.encode([`uint`, `uint16`], [eth(0.5), AAVE_ASSET_ID.WETH]), // weth aaveV3 borrow
      encoder.encode([`uint`], [eth(`1.4`)]) // hf check >1.01
    ],
    [[], [1, 0], [0, 0], [0]]
  )

  console.log(`\n>> After <<`)
  console.log(
    `health Factor`,
    (+ethers.formatEther((await c_aaveV3Pool.getUserAccountData(stratAddress)).healthFactor)).toFixed(4)
  )
  await printBal()
  console.log(`protocol NAV`, ethers.formatEther(await _navHelper.getProtocolIau()))
  console.log(
    `pm NAV`,
    ethers.formatEther((await _navHelper.getVaultNav()) + (await _pnlAccountingHelper.getNavOfStrategy([])))
  )
  const { _isProfit, _pnl, _fee } = await _pnlAccountingHelper.getPnl([])
  console.log(`PNL is profit?`, _isProfit, `delta`, ethers.formatEther(_pnl), `fee`, ethers.formatEther(_fee))

  // uncomment to do accounting to mark to market
  // await _pnlHelper.doAccounting([])
}

const printBalanceOf = (address: string) => async (token: ERC20) => {
  const symbol = await token.symbol()
  const val = await token.balanceOf(address)
  console.log(`${address.slice(-4)} ${symbol}\t`, ethers.formatEther(val))

  return val
}

main().catch((e) => {
  console.log(e)
  process.exit(1)
})
