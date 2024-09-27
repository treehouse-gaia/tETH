import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe(`StrategyStorage`, () => {
  async function deployFixture() {
    const [deployer, mockAsset, mockStrategyAddress, u2] = await ethers.getSigners()
    const strategyStorage = await (await ethers.getContractFactory(`StrategyStorage`)).deploy(deployer)

    const mockAction = await (await ethers.getContractFactory(`MockAction`)).deploy()
    const mockActionId = await mockAction.getId()

    return { strategyStorage, deployer, mockStrategyAddress, mockAsset, mockActionId, u2 }
  }

  describe(`storeStrategy()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage, mockStrategyAddress } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).storeStrategy(mockStrategyAddress, [], [])).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if already exist`, async () => {
      const { strategyStorage, mockStrategyAddress } = await loadFixture(deployFixture)

      await expect(strategyStorage.storeStrategy(mockStrategyAddress, [], []))
        .emit(strategyStorage, `StrategyCreated`)
        .withArgs(0, [], [])

      expect(await strategyStorage.getStrategyCount()).eq(1)
      expect(await strategyStorage.isActiveStrategy(await strategyStorage.getStrategyAddress(0))).eq(true)

      await expect(strategyStorage.storeStrategy(mockStrategyAddress, [], [])).revertedWithCustomError(
        strategyStorage,
        `AlreadyExist`
      )
    })
  })

  describe(`whitelistActions()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).whitelistActions(0, [])).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if already exist`, async () => {
      const { strategyStorage, mockStrategyAddress, mockActionId } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [mockActionId], [])

      await expect(strategyStorage.whitelistActions(0, [mockActionId])).revertedWithCustomError(
        strategyStorage,
        `AlreadyExist`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress, mockActionId } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.whitelistActions(0, [mockActionId]))
        .emit(strategyStorage, `ActionWhitelisted`)
        .withArgs(mockActionId)
    })
  })

  describe(`un-whitelistActions()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).unwhitelistActions(0, [])).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if doesnt exist`, async () => {
      const { strategyStorage, mockStrategyAddress, mockActionId } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.unwhitelistActions(0, [mockActionId])).revertedWithCustomError(
        strategyStorage,
        `DoesNotExist`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress, mockActionId } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [mockActionId], [])

      await expect(strategyStorage.unwhitelistActions(0, [mockActionId]))
        .emit(strategyStorage, `ActionUnwhitelisted`)
        .withArgs(mockActionId)
    })
  })

  describe(`whitelistAssets()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).whitelistAssets(0, [])).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if already exist`, async () => {
      const { strategyStorage, mockStrategyAddress, mockAsset } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [mockAsset])

      await expect(strategyStorage.whitelistAssets(0, [mockAsset])).revertedWithCustomError(
        strategyStorage,
        `AlreadyExist`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress, mockAsset } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.whitelistAssets(0, [mockAsset]))
        .emit(strategyStorage, `AssetWhitelisted`)
        .withArgs(mockAsset)
    })
  })

  describe(`un-whitelistAssets()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).unwhitelistAssets(0, [])).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`should revert if doesnt exist`, async () => {
      const { strategyStorage, mockStrategyAddress, mockAsset } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.unwhitelistAssets(0, [mockAsset])).revertedWithCustomError(
        strategyStorage,
        `DoesNotExist`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress, mockAsset } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [mockAsset])

      await expect(strategyStorage.unwhitelistAssets(0, [mockAsset]))
        .emit(strategyStorage, `AssetUnwhitelisted`)
        .withArgs(mockAsset)
    })
  })

  describe(`pauseStrategy()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).pauseStrategy(0)).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.pauseStrategy(0)).emit(strategyStorage, `StrategyPaused`)

      expect(await strategyStorage.isActiveStrategy(await strategyStorage.getStrategyAddress(0))).eq(false)
    })
  })

  describe(`unpauseStrategy()`, () => {
    it(`should revert if not owner`, async () => {
      const [, u1] = await ethers.getSigners()
      const { strategyStorage } = await loadFixture(deployFixture)

      await expect(strategyStorage.connect(u1).unpauseStrategy(0)).revertedWithCustomError(
        strategyStorage,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`happy path`, async () => {
      const { strategyStorage, mockStrategyAddress } = await loadFixture(deployFixture)

      await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

      await expect(strategyStorage.pauseStrategy(0)).emit(strategyStorage, `StrategyPaused`)

      expect(await strategyStorage.isActiveStrategy(await strategyStorage.getStrategyAddress(0))).eq(false)

      await expect(strategyStorage.unpauseStrategy(0)).emit(strategyStorage, `StrategyUnpaused`)

      expect(await strategyStorage.isActiveStrategy(await strategyStorage.getStrategyAddress(0))).eq(true)
    })
  })

  it(`getStrategyAddress() should revert if strategyId doesn't exist`, async () => {
    const { strategyStorage } = await loadFixture(deployFixture)

    await expect(strategyStorage.getStrategyAddress(100)).revertedWithCustomError(strategyStorage, `DoesNotExist`)
  })

  it(`isAssetWhiteListed() should return false if asset not whitelisted`, async () => {
    const { strategyStorage, mockStrategyAddress, mockAsset } = await loadFixture(deployFixture)

    await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

    expect(await strategyStorage.isAssetWhitelisted(strategyStorage, mockAsset)).eq(false)
  })

  it(`isActionWhitelisted() should false if action not whitelisted`, async () => {
    const { strategyStorage, mockStrategyAddress, mockActionId } = await loadFixture(deployFixture)

    await strategyStorage.storeStrategy(mockStrategyAddress, [], [])

    expect(await strategyStorage.isActionWhitelisted(strategyStorage, mockActionId)).eq(false)
  })
})
