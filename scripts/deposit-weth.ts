import { ethers, ignition } from 'hardhat'
import { eth, impersonateAndRun } from './utils'
import { CONSTANTS } from '../ignition/constants'

import PnlModule from '../ignition/modules/Pnl'
import { NavHelper, PnlAccountingHelper, TreehouseRouter } from '../typechain-types'
import ProtocolPhaseOne from '../ignition/modules/ProtocolPhaseOne'

async function main() {
  const c_weth = await ethers.getContractAt(`IERC20`, CONSTANTS.WETH)
  const ethWhale = `0x57757E3D981446D585Af0D9Ae4d7DF6D64647806`

  const { tasset, treehouseRouter } = await ignition.deploy(ProtocolPhaseOne)
  const _treehouseRouter = treehouseRouter as unknown as TreehouseRouter

  const { navHelper, pnlAccountingHelper } = await ignition.deploy(PnlModule)
  const _navHelper = navHelper as unknown as NavHelper
  const _pnlAccountingHelper = pnlAccountingHelper as unknown as PnlAccountingHelper

  await impersonateAndRun(ethWhale, async (signer) => {
    await c_weth.connect(signer).approve(_treehouseRouter, ethers.MaxUint256)
    await _treehouseRouter.connect(signer).deposit(c_weth, eth(10))
  })

  console.log(`tasset bal`, ethers.formatEther(await tasset.balanceOf(ethWhale)))
  console.log(`protocol NAV`, ethers.formatEther(await _navHelper.getProtocolIau()))
  console.log(
    `pm NAV`,
    ethers.formatEther((await _navHelper.getVaultNav()) + (await _pnlAccountingHelper.getNavOfStrategy([])))
  )
  console.log(`done`)
}

main().catch((e) => {
  console.log(e)
  process.exit(1)
})
