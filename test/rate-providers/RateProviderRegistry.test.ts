import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import RateProviderModule from '../../ignition/modules/RateProvider'
import { ChainlinkRateProvider, RateProviderRegistry, WstETHRateProvider } from '../../typechain-types'
import { CONSTANTS } from '../../ignition/constants'

describe(`RateProviderModule`, () => {
  async function deployModuleFixture() {
    const { rpr, stethRp, wstethRp, usdEthRp } = await ignition.deploy(RateProviderModule)

    const WETH = await rpr.WETH()
    const stETH = CONSTANTS.STETH
    // @ts-expect-error assert types
    return { rpr, stethRp, wstethRp, usdEthRp, WETH, stETH } as {
      rpr: RateProviderRegistry
      stethRp: ChainlinkRateProvider
      wstethRp: WstETHRateProvider
      usdEthRp: ChainlinkRateProvider
      WETH: string
      stETH: string
    }
  }

  describe(`update()`, () => {
    it(`should revert when not called by owner()`, async () => {
      const [, mockAsset, mockRateProvider, u1] = await ethers.getSigners()
      const { rpr } = await loadFixture(deployModuleFixture)
      await expect(rpr.connect(u1).update(mockAsset, mockRateProvider)).revertedWithCustomError(
        rpr,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert when asset or rate provider is address(0)`, async () => {
      const [, mockAsset, mockRateProvider] = await ethers.getSigners()
      const { rpr } = await loadFixture(deployModuleFixture)
      await expect(rpr.update(ethers.ZeroAddress, mockRateProvider)).revertedWithCustomError(rpr, `InvalidAddress`)

      await expect(rpr.update(mockAsset, ethers.ZeroAddress)).revertedWithCustomError(rpr, `InvalidAddress`)
    })

    it(`should emit RateProviderUpdated() event`, async () => {
      const [, mockAsset, mockRateProvider] = await ethers.getSigners()
      const { rpr } = await loadFixture(deployModuleFixture)
      await expect(rpr.update(mockAsset, mockRateProvider))
        .emit(rpr, `RateProviderUpdated`)
        .withArgs(mockAsset, mockRateProvider, ethers.ZeroAddress)
    })
  })

  describe(`check()`, () => {
    it(`should not revert if asset is WETH`, async () => {
      const { rpr, WETH } = await loadFixture(deployModuleFixture)

      await expect(rpr.checkHasRateProvider(WETH)).not.reverted
    })

    it(`should revert if no rateProvider`, async () => {
      const [, mockRp] = await ethers.getSigners()
      const { rpr } = await loadFixture(deployModuleFixture)

      await expect(rpr.checkHasRateProvider(mockRp)).revertedWithCustomError(rpr, `RateProviderNotFound`)
    })

    it(`happy path`, async () => {
      const [, mockAsset, mockRateProvider] = await ethers.getSigners()

      const { rpr } = await loadFixture(deployModuleFixture)

      await rpr.update(mockAsset, mockRateProvider)
      await expect(rpr.checkHasRateProvider(mockAsset)).not.reverted
    })
  })

  describe(`getRateInEth()`, () => {
    it(`should return 1e18 if asset is WETH`, async () => {
      const { rpr, WETH } = await loadFixture(deployModuleFixture)

      expect(await rpr.getRateInEth(WETH)).eq(BigInt(1e18))
    })

    it(`should revert if no rateProvider`, async () => {
      const [, mockRp] = await ethers.getSigners()
      const { rpr } = await loadFixture(deployModuleFixture)

      await expect(rpr.getRateInEth(mockRp)).revertedWithCustomError(rpr, `RateProviderNotFound`)
    })

    it(`happy path`, async () => {
      const { rpr, stethRp, stETH } = await loadFixture(deployModuleFixture)

      const price = await stethRp.getRate()
      expect(await rpr.getRateInEth(stETH)).eq(price)
    })
  })
})
