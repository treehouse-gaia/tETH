import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { eth } from '../scripts/utils'

describe(`TreehouseAccounting`, function () {
  async function deployFixture() {
    const [deployer, , , , , , mockVault, mockTreasury] = await ethers.getSigners()
    const FEE = 2000
    const EXECUTOR = deployer

    const mockWETH = await (await ethers.getContractFactory(`MockErc20`)).deploy(`WETH`, `WETH`)
    const mockUnderlying = await (await ethers.getContractFactory(`MockErc20`)).deploy(`Underlying`, `UNDER`)
    const iau = await (await ethers.getContractFactory(`InternalAccountingUnit`)).deploy(deployer, mockUnderlying)

    const tasset = await (await ethers.getContractFactory(`TAsset`)).deploy(deployer, iau, `TETH`, `TETH`)
    const accounting = await (
      await ethers.getContractFactory(`TreehouseAccounting`)
    ).deploy(deployer, iau, tasset, mockTreasury, EXECUTOR, FEE)

    await iau.addMinter(accounting)

    // obtain 10 tasset
    await iau.addMinter(deployer)
    await iau.mintTo(deployer, eth(10))
    await iau.approve(tasset, ethers.MaxUint256)
    await tasset.deposit(eth(10), deployer)
    await iau.removeMinter(deployer)
    expect(await tasset.balanceOf(deployer)).eq(eth(10))

    return { iau, tasset, accounting, mockVault, mockTreasury, mockWETH }
  }

  describe(`mark()`, () => {
    it(`should revert if not owner or executor`, async () => {
      const [, u1] = await ethers.getSigners()
      const { accounting } = await loadFixture(deployFixture)
      await expect(accounting.connect(u1).mark(0, 0, 0)).revertedWithCustomError(accounting, `Unauthorized`)
    })

    it(`mint - happy path`, async () => {
      const { accounting, tasset, iau, mockTreasury } = await loadFixture(deployFixture)
      await expect(accounting.mark(1, eth(10.1), eth(0.1)))
        .emit(accounting, `Marked`)
        .withArgs(1, eth(10.1), eth(0.1))

      expect(await tasset.balanceOf(mockTreasury)).eq(eth(0.1))
      expect(await tasset.totalSupply()).eq(eth(10.1))
      expect(await iau.totalSupply()).eq(eth(20.2))
      expect(await tasset.convertToAssets(eth(1))).closeTo(eth(2), 1)
    })

    it(`burn - happy path`, async () => {
      const { accounting, tasset, iau } = await loadFixture(deployFixture)
      await expect(accounting.mark(0, eth(1), 0))
        .emit(accounting, `Marked`)
        .withArgs(0, eth(1), 0)

      expect(await tasset.totalSupply()).eq(eth(10))
      expect(await iau.totalSupply()).eq(eth(9))
      expect(await tasset.convertToAssets(eth(1))).eq((eth(9) * BigInt(1e18)) / eth(10))
    })
  })

  it(`updateExecutor() should revert if not called by owner`, async () => {
    const [, u1, u2] = await ethers.getSigners()
    const { accounting } = await loadFixture(deployFixture)
    await expect(accounting.connect(u1).updateExecutor(u2)).revertedWithCustomError(
      accounting,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`updateTreasury() should revert if not called by owner`, async () => {
    const [, u1, u2] = await ethers.getSigners()
    const { accounting } = await loadFixture(deployFixture)
    await expect(accounting.connect(u1).updateTreasury(u2)).revertedWithCustomError(
      accounting,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`setFee() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { accounting } = await loadFixture(deployFixture)
    await expect(accounting.connect(u1).setFee(3000)).revertedWithCustomError(accounting, `OwnableUnauthorizedAccount`)
  })
})
