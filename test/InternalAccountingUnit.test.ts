import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { eth } from '../scripts/utils'

describe(`InternalAccountingUnit`, function () {
  async function deployFixture() {
    const [deployer, u1, u2, u3] = await ethers.getSigners()

    const mockUnderlying = await (await ethers.getContractFactory(`MockErc20`)).deploy(`Underlying`, `UNDER`)
    const iau = await (await ethers.getContractFactory(`InternalAccountingUnit`)).deploy(deployer, mockUnderlying)

    await iau.addMinter(deployer)
    await iau.mintTo(u1, eth(100))
    await iau.removeMinter(deployer)

    return { iau, mockUnderlying, deployer, u1, u2, u3 }
  }

  it(`should deploy with correct name and symbol`, async () => {
    const { iau, mockUnderlying } = await loadFixture(deployFixture)

    expect(await iau.name()).eq(`InternalAccountingUnit_` + (await mockUnderlying.name()))
    expect(await iau.symbol()).eq(`IAU_` + (await mockUnderlying.symbol()))
  })

  it(`should deploy with correct underlying asset`, async () => {
    const { iau, mockUnderlying } = await loadFixture(deployFixture)

    expect(await iau.getUnderlying()).eq(mockUnderlying)
  })

  describe(`_update() for both sendee and sender`, () => {
    it(`should revert if msg.sender != minter`, async () => {
      const { iau, u1, u2 } = await loadFixture(deployFixture)
      await expect(iau.connect(u1).transfer(u2, eth(1))).revertedWithCustomError(iau, `Unauthorized`)

      await iau.addMinter(u1)

      await expect(iau.connect(u1).transfer(u2, eth(1))).not.reverted
      expect(await iau.balanceOf(u2)).eq(eth(1))
    })

    it(`should be revert if from != minter`, async () => {
      const { iau, u1, u2, deployer } = await loadFixture(deployFixture)
      await iau.connect(u1).approve(deployer, ethers.MaxUint256)

      await expect(iau.transferFrom(u1, u2, eth(1))).revertedWithCustomError(iau, `Unauthorized`)

      await iau.addMinter(u1)

      await expect(iau.transferFrom(u1, u2, eth(1))).not.reverted
      expect(await iau.balanceOf(u2)).eq(eth(1))
    })

    it(`should be revert if to != minter`, async () => {
      const { iau, u1, u2, deployer } = await loadFixture(deployFixture)
      await iau.connect(u1).approve(deployer, ethers.MaxUint256)

      await expect(iau.transferFrom(u1, u2, eth(1))).revertedWithCustomError(iau, `Unauthorized`)

      await iau.addMinter(u2)

      await expect(iau.transferFrom(u1, u2, eth(1))).not.reverted
      expect(await iau.balanceOf(u2)).eq(eth(1))
    })
  })

  describe(`onlyOwner`, () => {
    it(`should revert if !owner && !timelock`, async () => {
      const { iau, u1 } = await loadFixture(deployFixture)
      await expect(iau.connect(u1).setTimelock(u1)).revertedWithCustomError(iau, `OwnableUnauthorizedAccount`)
    })

    it(`should be successful if owner && !timelock`, async () => {
      const { iau, u1 } = await loadFixture(deployFixture)
      await expect(iau.setTimelock(u1)).not.reverted
    })

    it(`should be successful if !owner && timelock`, async () => {
      const { iau, u1 } = await loadFixture(deployFixture)
      await iau.setTimelock(u1)
      await expect(iau.connect(u1).setTimelock(u1)).not.reverted
    })

    it(`should be successful owner && timelock`, async () => {
      const { iau, deployer, u1 } = await loadFixture(deployFixture)
      await iau.setTimelock(deployer)
      await expect(iau.setTimelock(u1)).not.reverted
    })
  })
})
