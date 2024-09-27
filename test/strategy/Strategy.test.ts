import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe(`Strategy`, function () {
  async function deployFixture() {
    const [deployer, mockExecutor, , , , mockVault] = await ethers.getSigners()
    const strategy = await (await ethers.getContractFactory(`Strategy`)).deploy(deployer, mockExecutor, mockVault)

    return { strategy, deployer, mockExecutor }
  }

  describe(`callExecute()`, () => {
    it(`should revert if not called by executor`, async () => {
      const { strategy } = await loadFixture(deployFixture)

      await expect(strategy.callExecute(ethers.ZeroAddress, `0x`)).revertedWithCustomError(strategy, `Unauthorized`)
    })

    it(`should revert if target is address(0)`, async () => {
      const { strategy, mockExecutor } = await loadFixture(deployFixture)

      await expect(strategy.connect(mockExecutor).callExecute(ethers.ZeroAddress, `0x`)).revertedWithCustomError(
        strategy,
        `Failed`
      )
    })

    it(`happy path`, async () => {
      const { strategy, mockExecutor } = await loadFixture(deployFixture)

      await expect(strategy.connect(mockExecutor).callExecute(mockExecutor, `0x`)).not.reverted
    })
  })

  describe(`execute()`, () => {
    it(`should revert if not executed by itself`, async () => {
      const { strategy } = await loadFixture(deployFixture)

      await expect(strategy.execute(ethers.ZeroAddress, `0x`)).revertedWithCustomError(strategy, `Unauthorized`)
    })
  })

  it(`setStrategyExecutor() revert if not owner`, async () => {
    const { strategy, mockExecutor } = await loadFixture(deployFixture)

    await expect(strategy.connect(mockExecutor).setStrategyExecutor(mockExecutor)).revertedWithCustomError(
      strategy,
      `OwnableUnauthorizedAccount`
    )
  })
})
