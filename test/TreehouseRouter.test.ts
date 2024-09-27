import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import { eth } from '../scripts/utils'
import TAssetModule from '../ignition/modules/TAsset'
import { InternalAccountingUnit, TAsset } from '../typechain-types'

describe(`TreehouseRouter`, function () {
  async function deployFixture() {
    const DEPOSIT_CAP = eth(15_000)
    const [deployer] = await ethers.getSigners()

    const mockWETH = await (await ethers.getContractFactory(`MockWeth`)).deploy()
    const mockstETH = await (await ethers.getContractFactory(`MockStETH`)).deploy(0, 0)
    const mockWSTETH = await (await ethers.getContractFactory(`MockWstEth`)).deploy(mockstETH)
    const mockCustomToken = await (await ethers.getContractFactory(`MockErc20`)).deploy(`CUSTOM`, `CUSTOM`)

    const module = await ignition.deploy(TAssetModule, {
      parameters: {
        TAssetModule: { underlyingToken: await mockWSTETH.getAddress() }
      }
    })

    const iau = module.iau as unknown as InternalAccountingUnit
    const tasset = module.tasset as unknown as TAsset
    const mockVault = await (
      await ethers.getContractFactory(`MockVault`)
    ).deploy(await tasset.getUnderlying(), await tasset.getAddress())

    const router = await (
      await ethers.getContractFactory(`TreehouseRouter`)
    ).deploy(deployer, mockWETH, mockstETH, mockWSTETH, mockVault, DEPOSIT_CAP)

    const underlyingToken = await ethers.getContractAt(`IERC20`, await tasset.getUnderlying())

    // router needs to be added for minting tasset
    await iau.addMinter(router)

    await mockVault.setAllAssetsAllowable(true)

    await mockWETH.approve(router, ethers.MaxUint256)
    await mockstETH.approve(router, ethers.MaxUint256)
    await mockWSTETH.approve(router, ethers.MaxUint256)
    await mockCustomToken.approve(router, ethers.MaxUint256)

    await mockWETH.deposit({ value: eth(100) })
    await mockstETH.submit(ethers.ZeroAddress, { value: eth(100) })
    await mockWSTETH.mintTo(deployer, eth(100))
    await mockCustomToken.mintTo(deployer, eth(100))

    return { iau, tasset, router, mockWETH, mockWSTETH, mockstETH, mockVault, mockCustomToken, underlyingToken }
  }

  describe(`deposit()`, () => {
    it(`should revert if paused`, async () => {
      const { router, mockWETH } = await loadFixture(deployFixture)

      await router.setPause(true)

      await expect(router.deposit(mockWETH, eth(1))).revertedWithCustomError(router, `EnforcedPause`)
    })

    it(`should revert if transferred ETH`, async () => {
      const [deployer] = await ethers.getSigners()
      const { router } = await loadFixture(deployFixture)

      await expect(
        deployer.sendTransaction({
          to: await router.getAddress(),
          value: eth(1)
        })
      ).revertedWithCustomError(router, `InvalidSender`)
    })

    it(`should revert if asset allowable but cannot convert to underlying`, async () => {
      const { router, mockCustomToken } = await loadFixture(deployFixture)

      await expect(router.deposit(mockCustomToken, eth(1))).revertedWithCustomError(
        router,
        `ConversionToUnderlyingFailed`
      )
    })

    it(`should revert if not allowable asset`, async () => {
      const { router, mockWETH, mockVault } = await loadFixture(deployFixture)
      await expect(router.deposit(mockWETH, eth(1))).not.reverted

      await mockVault.setAllAssetsAllowable(false)

      await expect(router.deposit(mockWETH, eth(1))).revertedWithCustomError(router, `NotAllowableAsset`)
    })

    it(`should revert if deposit cap exceeded`, async () => {
      const { router, mockWETH } = await loadFixture(deployFixture)

      await expect(router.deposit(mockWETH, eth(1))).not.reverted

      await router.setDepositCap(0)

      await expect(router.deposit(mockWETH, eth(1))).revertedWithCustomError(router, `DepositCapExceeded`)

      await router.setDepositCap(eth(1.9))
      await expect(router.deposit(mockWETH, eth(1))).revertedWithCustomError(router, `DepositCapExceeded`)

      await router.setDepositCap(eth(2))
      await expect(router.deposit(mockWETH, eth(1))).not.reverted

      await expect(router.deposit(mockWETH, eth(1))).revertedWithCustomError(router, `DepositCapExceeded`)
    })

    it(`should revert if no shares minted`, async () => {
      const { router, mockWETH } = await loadFixture(deployFixture)

      await expect(router.deposit(mockWETH, 0)).revertedWithCustomError(router, `NoSharesMinted`)
    })

    it(`stETH happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { router, tasset, mockstETH, mockVault, mockWSTETH } = await loadFixture(deployFixture)
      const depositAmount = eth(1)
      const underlyingAmount = await mockWSTETH.getWstETHByStETH(depositAmount)

      await expect(router.deposit(mockstETH, depositAmount))
        .emit(router, `Deposited`)
        .withArgs(await mockstETH.getAddress(), underlyingAmount, underlyingAmount)

      expect(await mockWSTETH.balanceOf(mockVault)).eq(underlyingAmount)
      expect(await tasset.balanceOf(deployer)).eq(underlyingAmount)
    })

    it(`wstETH happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { router, tasset, mockVault, mockWSTETH } = await loadFixture(deployFixture)
      const depositAmount = eth(1)

      await expect(router.deposit(mockWSTETH, depositAmount))
        .emit(router, `Deposited`)
        .withArgs(await mockWSTETH.getAddress(), depositAmount, depositAmount)

      expect(await mockWSTETH.balanceOf(mockVault)).eq(depositAmount)
      expect(await tasset.balanceOf(deployer)).eq(depositAmount)
    })

    it(`WETH happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { router, tasset, mockWETH, mockVault, mockWSTETH } = await loadFixture(deployFixture)
      const depositAmount = eth(1)
      const underlyingAmount = await mockWSTETH.getWstETHByStETH(depositAmount)

      await expect(router.deposit(mockWETH, depositAmount))
        .emit(router, `Deposited`)
        .withArgs(await mockWETH.getAddress(), underlyingAmount, underlyingAmount)

      expect(await mockWSTETH.balanceOf(mockVault)).eq(underlyingAmount)
      expect(await tasset.balanceOf(deployer)).eq(underlyingAmount)
    })
  })

  describe(`depositETH()`, () => {
    it(`should revert if paused`, async () => {
      const { router } = await loadFixture(deployFixture)

      await router.setPause(true)

      await expect(router.depositETH({ value: eth(1) })).revertedWithCustomError(router, `EnforcedPause`)
    })

    it(`should revert if deposit cap exceeded`, async () => {
      const { router } = await loadFixture(deployFixture)

      await router.setDepositCap(0)

      await expect(router.depositETH({ value: eth(1) })).revertedWithCustomError(router, `DepositCapExceeded`)
    })

    it(`should revert if no shares minted`, async () => {
      const { router } = await loadFixture(deployFixture)
      const depositAmount = eth(0)

      await expect(router.depositETH({ value: depositAmount })).revertedWithCustomError(router, `NoSharesMinted`)
    })

    it(`happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { router, tasset, mockVault, mockWSTETH, underlyingToken } = await loadFixture(deployFixture)
      const depositAmount = eth(1)
      const underlyingAmount = await mockWSTETH.getWstETHByStETH(depositAmount)

      await expect(router.depositETH({ value: depositAmount }))
        .emit(router, `Deposited`)
        .withArgs(`0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`, underlyingAmount, underlyingAmount)

      expect(await underlyingToken.balanceOf(mockVault)).eq(underlyingAmount)
      expect(await tasset.balanceOf(deployer)).eq(underlyingAmount)
    })
  })

  it(`setDepositCap() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { router } = await loadFixture(deployFixture)

    await expect(router.connect(u1).setDepositCap(2)).revertedWithCustomError(router, `OwnableUnauthorizedAccount`)
  })
})
