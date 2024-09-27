import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { ethers } from 'hardhat'
import VaultModule from './Vault'
import { CONSTANTS } from '../constants'
import TAssetModule from './TAsset'

const ProtocolPhaseOne = buildModule(`ProtocolPhaseOne`, (m) => {
  const deployer = m.getAccount(0)

  const weth = m.getParameter(`weth`, CONSTANTS.WETH)
  const steth = m.getParameter(`steth`, CONSTANTS.STETH)
  const wsteth = m.getParameter(`wsteth`, CONSTANTS.WSTETH)
  const depositCap = m.getParameter(`depositCap`, ethers.parseUnits(`15000`))

  const { iau, tasset } = m.useModule(TAssetModule)
  const { vault } = m.useModule(VaultModule)

  const simpleStakingERC20 = m.contract(`SimpleStakingERC20`, [deployer])

  const treehouseRouter = m.contract(`TreehouseRouter`, [deployer, weth, steth, wsteth, vault, depositCap])

  // minters can mint/burn IAUs, and deposit/withdraw from TAsset
  m.call(iau, `addMinter`, [treehouseRouter], { id: `addMinter_TreehouseRouter` })

  // add allowable assets
  m.call(vault, `addAllowableAsset`, [weth], { id: `addAllowableAsset_WETH` })
  m.call(vault, `addAllowableAsset`, [steth], { id: `addAllowableAsset_STETH` })
  m.call(vault, `addAllowableAsset`, [wsteth], { id: `addAllowableAsset_WSTETH` })

  // TODO: add curve pool to staking
  // TODO: transfer ownships to multisig

  return {
    iau,
    tasset,
    treehouseRouter,
    vault,
    simpleStakingERC20
  }
})

export default ProtocolPhaseOne
