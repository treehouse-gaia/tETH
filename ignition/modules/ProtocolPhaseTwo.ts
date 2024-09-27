import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import ProtocolPhaseOne from './ProtocolPhaseOne'

const ProtocolPhaseTwo = buildModule(`ProtocolPhaseTwo`, (m) => {
  const deployer = m.getAccount(0)
  const TREASURY = deployer //TODO
  const ACCOUNTING_EXECUTOR = deployer //TODO

  const protocolFee = m.getParameter(`protocolFee`, 2000)
  const tassetRedemptionFee = m.getParameter(`tassetRedemptionFee`, 5)
  const { iau, tasset, vault, treehouseRouter } = m.useModule(ProtocolPhaseOne)

  const treehouseAccounting = m.contract(`TreehouseAccounting`, [
    deployer,
    iau,
    tasset,
    TREASURY,
    ACCOUNTING_EXECUTOR,
    protocolFee
  ])

  const treehouseRedemption = m.contract(`TreehouseRedemption`, [deployer, vault])

  m.call(treehouseRedemption, `setRedemptionFee`, [tassetRedemptionFee])

  //set redemption address in vault
  m.call(vault, `setRedemption`, [treehouseRedemption], { id: `setRedemption_treehouseRedemption` })

  // minters can mint/burn IAUs, and deposit/withdraw from TAsset
  m.call(iau, `addMinter`, [treehouseAccounting], { id: `addMinter_TreehouseAccounting` })
  m.call(iau, `addMinter`, [treehouseRedemption], { id: `addMinter_TreehouseRedemption` })

  return {
    iau,
    tasset,
    treehouseRouter,
    treehouseAccounting,
    treehouseRedemption,
    vault
  }
})

export default ProtocolPhaseTwo
