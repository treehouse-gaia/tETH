import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { camelcase, getActionIdFromName } from './utils'

// deploy actions, actionregistry and write actions
const ActionModule = buildModule(`ActionModule`, (m) => {
  const deployer = m.getAccount(0)
  const actionRegistry = m.contract(`ActionRegistry`, [deployer])

  const actionArray = [
    // Lido
    m.contract(`LidoStake`),
    m.contract(`LidoWrap`),
    m.contract(`LidoUnwrap`),
    m.contract(`LidoWithdrawStart`),
    m.contract(`LidoWithdrawClaim`),
    // Aave
    m.contract(`AaveV3SetEMode`),
    m.contract(`AaveV3Supply`),
    m.contract(`AaveV3Borrow`),
    m.contract(`AaveV3Payback`),
    m.contract(`AaveV3Withdraw`),
    // Vault
    m.contract(`VaultPull`),
    m.contract(`VaultSend`),
    // Checkers
    m.contract(`AaveV3HealthFactorCheck`),
    m.contract(`AssertCheck`)
  ] as const

  const actionIdsArray = actionArray.map((e) => m.staticCall(e, `getId`))

  actionArray.map((futureAction, i) =>
    m.call(actionRegistry, `addNewContract`, [actionIdsArray[i], futureAction], {
      id: `addNewContract_${futureAction.contractName}_${getActionIdFromName(futureAction.contractName)}`
    })
  )

  return {
    ...actionArray.reduce(
      (a, e) => ({ ...a, [camelcase(e.contractName)]: e }),
      {} as {
        [name in Uncapitalize<(typeof actionArray)[number][`contractName`]>]: (typeof actionArray)[number]
      }
    ),
    actionRegistry
  }
})

export default ActionModule
