import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import VaultModule from '../ignition/modules/Vault'
import { Vault } from '../typechain-types'
import { CONSTANTS } from '../ignition/constants'
import { eth } from '../scripts/utils'

describe(`Vault`, function () {
  async function deployModuleFixture() {
    const { vault } = await ignition.deploy(VaultModule)
    const stETH = CONSTANTS.STETH
    const WETH = CONSTANTS.WETH

    const mockToken = await (await ethers.getContractFactory(`MockErc20`)).deploy(`MOCK`, `MOCK`)

    const mockStratStorage = await (await ethers.getContractFactory(`MockStrategyStorage`)).deploy()

    await (vault as unknown as Vault).setStrategyStorage(mockStratStorage)
    // @ts-expect-error assert types
    return { vault, mockStratStorage, mockToken, stETH, WETH } as {
      vault: Vault
      mockStratStorage: typeof mockStratStorage
      mockToken: typeof mockToken
      stETH: string
      WETH: string
    }
  }

  describe(`addAllowableAsset()`, () => {
    it(`should revert if not called by owner`, async () => {
      const [, mockAsset, u1] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.connect(u1).addAllowableAsset(mockAsset)).revertedWithCustomError(
        vault,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if > 18 decimals`, async () => {
      const { vault, mockToken } = await loadFixture(deployModuleFixture)

      await mockToken.setDecimals(20)

      await expect(vault.addAllowableAsset(mockToken)).revertedWithCustomError(vault, `UnsupportedDecimals`)
    })

    it(`should revert if no existing rate provider`, async () => {
      const [, mockAsset] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.addAllowableAsset(mockAsset)).reverted
    })

    it(`should revert if already allowable`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      await expect(vault.addAllowableAsset(stETH)).not.reverted
      await expect(vault.addAllowableAsset(stETH)).revertedWithCustomError(vault, `Failed`)
    })

    it(`happy path - should emit event`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      await expect(vault.addAllowableAsset(stETH)).emit(vault, `AllowableAssetAdded`).withArgs(stETH)
    })
  })

  describe(`removeAllowableAsset()`, () => {
    it(`should revert if not called by owner`, async () => {
      const [, mockAsset, u1] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.connect(u1).removeAllowableAsset(mockAsset)).revertedWithCustomError(
        vault,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if doesn't exist`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      await expect(vault.removeAllowableAsset(stETH)).revertedWithCustomError(vault, `Failed`)
    })

    it(`happy path - should emit event`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      await vault.addAllowableAsset(stETH)
      await expect(vault.removeAllowableAsset(stETH)).emit(vault, `AllowableAssetRemoved`).withArgs(stETH)
    })
  })

  describe(`setRedemption()`, () => {
    it(`should revert if not called by owner`, async () => {
      const [, mockAddress, u1] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.connect(u1).setRedemption(mockAddress)).revertedWithCustomError(
        vault,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if address 0`, async () => {
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.setRedemption(ethers.ZeroAddress)).revertedWithCustomError(vault, `InvalidAddress`)
    })

    it(`should set/revoke underlying approval for redemption new/old contract`, async () => {
      const [, mockAddress, mockAddress2] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      const underlying = await ethers.getContractAt(`IERC20`, await vault.getUnderlying())

      // initial redemption
      await vault.setRedemption(mockAddress)
      expect(await underlying.allowance(vault, mockAddress)).eq(ethers.MaxUint256)

      // set new redemption
      await vault.setRedemption(mockAddress2)
      expect(await underlying.allowance(vault, mockAddress2)).eq(ethers.MaxUint256)
      expect(await underlying.allowance(vault, mockAddress)).eq(0)
    })

    it(`happy path - should emit event`, async () => {
      const [, mockAddress] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.setRedemption(mockAddress))
        .emit(vault, `RedemptionUpdated`)
        .withArgs(mockAddress, ethers.ZeroAddress)
    })
  })

  it(`getAllowableAssets()`, async () => {
    const { vault, stETH } = await loadFixture(deployModuleFixture)
    await vault.addAllowableAsset(stETH)
    expect(await vault.getAllowableAssets()).deep.eq([stETH])
  })

  it(`getAllowableAssetCount()`, async () => {
    const { vault, stETH } = await loadFixture(deployModuleFixture)
    await vault.addAllowableAsset(stETH)
    expect(await vault.getAllowableAssetCount()).eq(1)
  })

  describe(`isAllowableAsset()`, () => {
    it(`should revert if address(0)`, async () => {
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.isAllowableAsset(ethers.ZeroAddress)).revertedWithCustomError(vault, `InvalidAddress`)
    })

    it(`should return false if not allowable`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      expect(await vault.isAllowableAsset(stETH)).eq(false)
    })

    it(`should return true if allowable`, async () => {
      const { vault, stETH } = await loadFixture(deployModuleFixture)
      await vault.addAllowableAsset(stETH)
      expect(await vault.isAllowableAsset(stETH)).eq(true)
    })
  })

  describe(`setStrategyStorage()`, () => {
    it(`should revert if not called by owner`, async () => {
      const [, mockAddress, u1] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      await expect(vault.connect(u1).setStrategyStorage(mockAddress)).revertedWithCustomError(
        vault,
        `OwnableUnauthorizedAccount`
      )
    })
    it(`happy path - should emit event`, async () => {
      const [, mockAddress] = await ethers.getSigners()
      const { vault } = await loadFixture(deployModuleFixture)
      const oldStratStorage = await vault.strategyStorage()
      await expect(vault.setStrategyStorage(mockAddress))
        .emit(vault, `StrategyStorageUpdated`)
        .withArgs(mockAddress, oldStratStorage)
    })
  })

  describe(`withdraw()`, () => {
    it(`should revert if isActiveStrategy() false`, async () => {
      const { vault, mockToken } = await loadFixture(deployModuleFixture)

      await expect(vault.withdraw(mockToken, eth(1))).revertedWithCustomError(vault, `InvalidStrategy`)
    })

    it(`should revert if not whitelisted asset`, async () => {
      const { vault, mockToken, mockStratStorage } = await loadFixture(deployModuleFixture)

      await mockStratStorage.set(true, false)
      await expect(vault.withdraw(mockToken, eth(1))).revertedWithCustomError(vault, `InvalidStrategy`)
    })

    it(`happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { vault, mockToken, mockStratStorage } = await loadFixture(deployModuleFixture)
      await mockToken.mintTo(vault, eth(1))
      expect(await vault.strategyStorage()).eq(mockStratStorage)
      await mockStratStorage.set(true, true)

      await vault.withdraw(mockToken, eth(1))
      expect(await mockToken.balanceOf(deployer)).eq(eth(1))
    })
  })
})
