import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import { CONSTANTS } from '../../ignition/constants'
import { eth } from '../../scripts/utils'

describe(`PnlAccountingHelper`, () => {
  async function deployFixture() {
    const [deployer, u1, , , , , mockStrategy] = await ethers.getSigners()

    const DEVIATION = 200
    const { WETH, WSTETH } = CONSTANTS
    const mockNavHelper = await (await ethers.getContractFactory(`MockNavHelper`)).deploy()

    const mockTreehouseAccounting = await (await ethers.getContractFactory(`MockTreehouseAccounting`)).deploy()
    await mockTreehouseAccounting.setFee(0)

    const pnlAccountingHelper = await (
      await ethers.getContractFactory(`PnlAccountingHelper`)
    ).deploy(deployer, WETH, WSTETH, mockNavHelper, mockStrategy, mockTreehouseAccounting, DEVIATION)

    return { pnlAccountingHelper, mockNavHelper, mockTreehouseAccounting, deployer, u1 }
  }

  it(`updateExecutor() should revert if not owner`, async () => {
    const { pnlAccountingHelper, u1 } = await loadFixture(deployFixture)
    await expect(pnlAccountingHelper.connect(u1).updateExecutor(pnlAccountingHelper)).revertedWithCustomError(
      pnlAccountingHelper,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`setDeviation() should revert if not owner`, async () => {
    const { pnlAccountingHelper, u1 } = await loadFixture(deployFixture)
    await expect(pnlAccountingHelper.connect(u1).setDeviation(100)).revertedWithCustomError(
      pnlAccountingHelper,
      `OwnableUnauthorizedAccount`
    )
  })

  describe(`doAccounting()`, () => {
    it(`should revert if not owner`, async () => {
      const { pnlAccountingHelper, u1 } = await loadFixture(deployFixture)
      await expect(pnlAccountingHelper.connect(u1).doAccounting([])).revertedWithCustomError(
        pnlAccountingHelper,
        `Unauthorized`
      )
    })

    it(`should revert if pnl deviation exceeded`, async () => {
      const { pnlAccountingHelper, mockNavHelper } = await loadFixture(deployFixture)

      await mockNavHelper.setProtocolIau(eth(100))

      await mockNavHelper.setVaultNav(eth(1))
      await mockNavHelper.setAaveV3Nav(eth(10))
      await mockNavHelper.setTokensNav(eth(90))

      await pnlAccountingHelper.setDeviation(0)

      await expect(pnlAccountingHelper.doAccounting([])).revertedWithCustomError(
        pnlAccountingHelper,
        `DeviationExceeded`
      )

      await pnlAccountingHelper.setDeviation(1000)
      await expect(pnlAccountingHelper.doAccounting([])).not.reverted
    })
  })
})
