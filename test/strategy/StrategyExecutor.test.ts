import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe(`StrategyExecutor`, function () {
  async function deployFixture() {
    const [deployer, u2, , , , mockVault] = await ethers.getSigners()
    const strategy = await (await ethers.getContractFactory(`Strategy`)).deploy(deployer, deployer, mockVault)

    const mockActionExecutor = await (await ethers.getContractFactory(`MockActionExecutor`)).deploy()

    const mockSS = await (await ethers.getContractFactory(`MockStrategyStorage`)).deploy()

    await mockSS.setStrategyAddress(strategy)
    const strategyExecutor = await (
      await ethers.getContractFactory(`StrategyExecutor`)
    ).deploy(deployer, mockActionExecutor, mockSS)

    await strategy.setStrategyExecutor(strategyExecutor)

    return { strategyExecutor, mockSS, mockActionExecutor, strategy, deployer, u2 }
  }

  describe(`executeOnStrategy()`, () => {
    it(`should revert if not executor`, async () => {
      const { strategyExecutor, u2 } = await loadFixture(deployFixture)

      await expect(strategyExecutor.connect(u2).executeOnStrategy(0, [], [], [[]])).revertedWithCustomError(
        strategyExecutor,
        `Unauthorized`
      )
    })

    it(`should revert if not active strategy`, async () => {
      const { strategyExecutor, mockSS, u2 } = await loadFixture(deployFixture)

      await strategyExecutor.updateExecutor(u2, true)
      await mockSS.set(false, false)
      await mockSS.setActionWhitelisted(false)

      await expect(strategyExecutor.connect(u2).executeOnStrategy(0, [], [], [[]])).revertedWithCustomError(
        strategyExecutor,
        `StrategyNotActive`
      )
    })

    it(`should revert if actionIdss arr and calldata arr len mismatch`, async () => {
      const { strategyExecutor, mockSS, u2 } = await loadFixture(deployFixture)

      await strategyExecutor.updateExecutor(u2, true)
      await mockSS.set(true, false)
      await mockSS.setActionWhitelisted(false)

      await expect(strategyExecutor.connect(u2).executeOnStrategy(0, [], [`0x1234`], [[]])).revertedWithCustomError(
        strategyExecutor,
        `ArrayLengthMismatch`
      )
    })

    it(`should revert if action not whitelisted`, async () => {
      const { strategyExecutor, mockSS, u2 } = await loadFixture(deployFixture)

      await strategyExecutor.updateExecutor(u2, true)
      await mockSS.set(true, false)
      await mockSS.setActionWhitelisted(false)

      await expect(
        strategyExecutor.connect(u2).executeOnStrategy(0, [`0x11111111`], [`0x1234`], [[]])
      ).revertedWithCustomError(strategyExecutor, `ActionNotWhitelisted`)
    })

    it(`happy path`, async () => {
      const { strategyExecutor, mockSS, u2 } = await loadFixture(deployFixture)

      await strategyExecutor.updateExecutor(u2, true)
      await mockSS.set(true, false)
      await mockSS.setActionWhitelisted(true)

      await expect(strategyExecutor.connect(u2).executeOnStrategy(0, [`0x11111111`], [`0x1234`], [[0, 0]]))
        .emit(strategyExecutor, `ExecutionEvent`)
        .withArgs([`0x11111111`], 0)
    })
  })

  it(`updateExecutor() should revert if not owner`, async () => {
    const { strategyExecutor, u2 } = await loadFixture(deployFixture)

    await expect(strategyExecutor.connect(u2).updateExecutor(u2, true)).revertedWithCustomError(
      strategyExecutor,
      `OwnableUnauthorizedAccount`
    )
  })
})
