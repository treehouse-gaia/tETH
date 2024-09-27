import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import { eth } from '../scripts/utils'
import TAssetModule from '../ignition/modules/TAsset'
import { InternalAccountingUnit, TAsset } from '../typechain-types'

describe(`Redemption`, function () {
  async function deployFixture() {
    const [deployer] = await ethers.getSigners()

    const mockstETH = await (await ethers.getContractFactory(`MockStETH`)).deploy(0, 0)
    const mockWSTETH = await (await ethers.getContractFactory(`MockWstEth`)).deploy(mockstETH)

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

    const redemption = await (await ethers.getContractFactory(`TreehouseRedemption`)).deploy(deployer, mockVault)

    // obtain 10 tasset
    await iau.addMinter(deployer)
    await iau.mintTo(deployer, eth(10))
    await iau.approve(tasset, ethers.MaxUint256)
    await tasset.deposit(eth(10), deployer)

    expect(await tasset.balanceOf(deployer)).eq(eth(10))

    // redemption needs to be added for burning when finalizing redeem
    await iau.addMinter(redemption)

    //approve redeem contract to pull tasset from user(deployer in this case)
    await tasset.approve(redemption, ethers.MaxUint256)

    //fund vault with 100 underlying
    await mockWSTETH.mintTo(mockVault, eth(100))

    return { iau, tasset, redemption }
  }

  async function deployFixturesRedeeming() {
    const [deployer] = await ethers.getSigners()

    const mockstETH = await (await ethers.getContractFactory(`MockStETH`)).deploy(0, 0)
    const mockWSTETH = await (await ethers.getContractFactory(`MockWstEth`)).deploy(mockstETH)

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

    const redemption = await (await ethers.getContractFactory(`TreehouseRedemption`)).deploy(deployer, mockVault)

    // obtain 10 tasset
    await iau.addMinter(deployer)
    await iau.mintTo(deployer, eth(10))
    await iau.approve(tasset, ethers.MaxUint256)
    await tasset.deposit(eth(10), deployer)
    expect(await tasset.balanceOf(deployer)).eq(eth(10))

    // redemption needs to be added for burning when finalizing redeem
    await iau.addMinter(redemption)

    //approve redeem contract to pull tasset from user(deployer in this case)
    await tasset.approve(redemption, ethers.MaxUint256)

    await mockVault.setRedemption(redemption)

    //fund vault with 100 underlying
    await mockWSTETH.mintTo(mockVault, eth(100))

    await redemption.setMinRedeem(1)
    await redemption.redeem(eth(1))
    await time.increase(86400)
    await redemption.redeem(eth(2))

    return { iau, tasset, redemption, mockWSTETH, mockVault }
  }

  describe(`redeem()`, () => {
    it(`should revert on pause`, async () => {
      const { redemption } = await loadFixture(deployFixture)

      await redemption.setPause(true)
      await expect(redemption.redeem(eth(1))).revertedWithCustomError(redemption, `EnforcedPause`)
    })

    it(`should revert if minimum redeem amount not met`, async () => {
      const { redemption } = await loadFixture(deployFixture)

      await expect(redemption.redeem(eth(1))).revertedWithCustomError(redemption, `MinimumNotMet`)
    })

    it(`redeem happy path - should emit event`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, tasset, iau } = await loadFixture(deployFixture)
      await redemption.setMinRedeem(1)

      const redeemer = deployer
      const redeemAmount = eth(1)

      // simulate accounting with profit of 0.1 eth
      await iau.mintTo(tasset, eth(0.1))

      const assetsReturned = await tasset.previewRedeem(redeemAmount)

      expect(await redemption.redeem(redeemAmount))
        .emit(redemption, `Redeemed`)
        .withArgs(redeemer, redeemAmount, assetsReturned)

      expect(await redemption.getRedeemLength(redeemer)).eq(1)
      expect((await redemption.getRedeemInfo(redeemer, 0)).toString()).eq(
        `${await time.latest()},${redeemAmount},${assetsReturned.toString()},${eth(`1.1`)}`
      )
      expect(await redemption.redeeming(redeemer)).eq(redeemAmount)

      const redeemAmount2 = eth(2)
      const assetsReturned2 = await tasset.previewRedeem(redeemAmount2)

      await redemption.redeem(redeemAmount2)

      expect(await redemption.getRedeemLength(redeemer)).eq(2)
      expect((await redemption.getRedeemInfo(redeemer, 1)).toString()).eq(
        `${await time.latest()},${redeemAmount2},${assetsReturned2.toString()},${eth(`1.1`)}`
      )
      expect(await redemption.redeeming(redeemer)).eq(redeemAmount + redeemAmount2)
    })
  })

  describe(`finalizeRedeem()`, () => {
    it(`should revert on pause`, async () => {
      const { redemption } = await loadFixture(deployFixture)

      await redemption.setPause(true)
      await expect(redemption.finalizeRedeem(0)).revertedWithCustomError(redemption, `EnforcedPause`)
    })

    it(`should revert on non-existent redeem`, async () => {
      const { redemption } = await loadFixture(deployFixture)

      await expect(redemption.finalizeRedeem(10)).revertedWithCustomError(redemption, `RedemptionNotFound`)
    })

    it(`should revert if still waiting`, async () => {
      const { redemption } = await loadFixture(deployFixturesRedeeming)

      await expect(redemption.finalizeRedeem(0)).revertedWithCustomError(redemption, `InWaitingPeriod`)
    })

    it(`should revert if insufficient funds in vault`, async () => {
      const { redemption, mockWSTETH, mockVault } = await loadFixture(deployFixturesRedeeming)
      const waitPeriod = await redemption.waitingPeriod()

      await mockWSTETH.burnFrom(mockVault, eth(100))
      await time.increase(waitPeriod - 86400n)

      await expect(redemption.finalizeRedeem(0)).revertedWithCustomError(redemption, `InsufficientFundsInVault`)
      await expect(redemption.finalizeRedeem(1)).revertedWithCustomError(redemption, `InWaitingPeriod`)
    })

    it(`happy path - finalize redeem with arb profits`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, iau, tasset, mockWSTETH } = await loadFixture(deployFixturesRedeeming)
      const redeemIndex0 = await redemption.getRedeemInfo(deployer, 0)

      // simulate accounting with profit of 0.1 eth
      await iau.mintTo(tasset, eth(0.1))
      await time.increase(86400 * 9)

      const redeemingBefore = await redemption.redeeming(deployer)
      const minReturn = redeemIndex0.asset
      const iauBalanceBefore = await iau.balanceOf(tasset)
      expect(await redemption.finalizeRedeem(0))
        .emit(redemption, `RedeemFinalized`)
        .withArgs(deployer, minReturn)

      expect(await mockWSTETH.balanceOf(deployer)).eq(minReturn)
      expect(await iau.balanceOf(redemption)).eq(0)
      expect(await redemption.redeeming(deployer)).eq(redeemingBefore - redeemIndex0.shares)
      expect(await redemption.getRedeemLength(deployer)).eq(1)
      expect(await iau.balanceOf(tasset)).eq(iauBalanceBefore - minReturn)
    })

    it(`happy path - finalize redeem with arb loss`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, iau, mockWSTETH, tasset } = await loadFixture(deployFixturesRedeeming)
      const redeemIndex0 = await redemption.getRedeemInfo(deployer, 0)

      // simulate accounting with profit of 0.1 eth
      await iau.burnFrom(tasset, eth(0.1))

      const initialBal = await iau.balanceOf(tasset)

      await time.increase(86400 * 9)
      const redeemingBefore = await redemption.redeeming(deployer)
      const minReturn = await tasset.previewRedeem(redeemIndex0.shares)

      expect(await redemption.finalizeRedeem(0))
        .emit(redemption, `RedeemFinalized`)
        .withArgs(deployer, minReturn)

      expect(await mockWSTETH.balanceOf(deployer)).eq(minReturn)
      expect(await iau.balanceOf(redemption)).eq(0)
      expect(await redemption.redeeming(deployer)).eq(redeemingBefore - redeemIndex0.shares)
      expect(await redemption.getRedeemLength(deployer)).eq(1)
      expect(await iau.balanceOf(tasset)).eq(initialBal - minReturn)
    })

    it(`happy path - finalize redeem with underlying profits`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, iau, mockWSTETH, tasset } = await loadFixture(deployFixturesRedeeming)
      const redeemIndex0 = await redemption.getRedeemInfo(deployer, 0)

      // simulate accounting with lrt share decrease 1.10 -> 1.12
      await mockWSTETH.setAssets(11200)
      await time.increase(86400 * 9)

      const redeemingBefore = await redemption.redeeming(deployer)
      const minReturn = BigInt(982142857142857142n)
      const iauBalanceBefore = await iau.balanceOf(tasset)
      expect(await redemption.finalizeRedeem(0))
        .emit(redemption, `RedeemFinalized`)
        .withArgs(deployer, minReturn)

      expect(await mockWSTETH.balanceOf(deployer)).eq(minReturn)
      expect(await iau.balanceOf(redemption)).eq(0)
      expect(await redemption.redeeming(deployer)).eq(redeemingBefore - redeemIndex0.shares)
      expect(await redemption.getRedeemLength(deployer)).eq(1)
      expect(await iau.balanceOf(tasset)).eq(iauBalanceBefore - minReturn)
    })

    it(`happy path - finalize redeem with underlying loss`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, iau, mockWSTETH, tasset } = await loadFixture(deployFixturesRedeeming)
      const redeemIndex0 = await redemption.getRedeemInfo(deployer, 0)

      // simulate accounting with lrt share decrease 1.10 -> 1.08
      await mockWSTETH.setAssets(10800)

      const initialBal = await iau.balanceOf(tasset)

      await time.increase(86400 * 9)
      const redeemingBefore = await redemption.redeeming(deployer)
      const minReturn = BigInt(981818181818181818n)

      expect(await redemption.finalizeRedeem(0))
        .emit(redemption, `RedeemFinalized`)
        .withArgs(deployer, minReturn)

      expect(await mockWSTETH.balanceOf(deployer)).eq(minReturn)
      expect(await iau.balanceOf(redemption)).eq(0)
      expect(await redemption.redeeming(deployer)).eq(redeemingBefore - redeemIndex0.shares)
      expect(await redemption.getRedeemLength(deployer)).eq(1)
      expect(await iau.balanceOf(tasset)).eq(initialBal - minReturn)
    })

    it(`should charge redemption fee on returned underlying`, async () => {
      const [deployer] = await ethers.getSigners()
      const { redemption, iau, mockWSTETH, tasset } = await loadFixture(deployFixturesRedeeming)
      const redeemIndex0 = await redemption.getRedeemInfo(deployer, 0)
      const redemptionFee = 5n

      await redemption.setRedemptionFee(redemptionFee)

      // simulate accounting with lrt share decrease 1.10 -> 1.08
      await mockWSTETH.setAssets(10800)

      const initialBal = await iau.balanceOf(tasset)

      await time.increase(86400 * 9)
      const redeemingBefore = await redemption.redeeming(deployer)
      const minReturn = 981818181818181818n

      const fee = (minReturn * redemptionFee) / 10_000n
      const minReturnAftFee = minReturn - fee

      expect(await redemption.finalizeRedeem(0))
        .emit(redemption, `RedeemFinalized`)
        .withArgs(deployer, minReturnAftFee, fee)

      expect(await mockWSTETH.balanceOf(deployer)).eq(minReturnAftFee)
      expect(await iau.balanceOf(redemption)).eq(0)
      expect(await redemption.redeeming(deployer)).eq(redeemingBefore - redeemIndex0.shares)
      expect(await redemption.getRedeemLength(deployer)).eq(1)
      expect(await iau.balanceOf(tasset)).eq(initialBal - minReturnAftFee)
    })
  })

  it(`setRedemptionFee() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { redemption } = await loadFixture(deployFixture)

    await expect(redemption.connect(u1).setRedemptionFee(2)).revertedWithCustomError(
      redemption,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`setWaitingPeriod() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { redemption } = await loadFixture(deployFixture)

    await expect(redemption.connect(u1).setWaitingPeriod(2)).revertedWithCustomError(
      redemption,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`setMinRedeem() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { redemption } = await loadFixture(deployFixture)

    await expect(redemption.connect(u1).setMinRedeem(2)).revertedWithCustomError(
      redemption,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`setPause() should revert if not called by owner`, async () => {
    const [, u1] = await ethers.getSigners()
    const { redemption } = await loadFixture(deployFixture)

    await expect(redemption.connect(u1).setPause(true)).revertedWithCustomError(
      redemption,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`getPendingRedeems() should return all in progress redemptions`, async () => {
    const [deployer] = await ethers.getSigners()
    const { redemption } = await loadFixture(deployFixturesRedeeming)
    await redemption.redeem(eth(`1.123`))

    // already had 2 in the fixture
    const allPendingRedeems = await redemption.getPendingRedeems(deployer)
    expect(allPendingRedeems.length).eq(3)
    expect(allPendingRedeems[2].shares).eq(eth(`1.123`))
    expect(allPendingRedeems[2].asset).eq(eth(`1.123`))
    expect(allPendingRedeems[2].baseRate).eq(eth(`1.1`))
  })
})
