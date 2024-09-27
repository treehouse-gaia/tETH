import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import { eth } from '../scripts/utils'
import TAssetModule from '../ignition/modules/TAsset'
import { InternalAccountingUnit, TAsset } from '../typechain-types'

describe(`TAsset`, function () {
  async function deployFixture() {
    const [deployer, u1, u2, u3] = await ethers.getSigners()
    const mockUnderlying = await (await ethers.getContractFactory(`MockErc20`)).deploy(`Underlying`, `UNDER`)

    const module = await ignition.deploy(TAssetModule, {
      parameters: {
        TAssetModule: { underlyingToken: await mockUnderlying.getAddress() }
      }
    })

    const iau = module.iau as unknown as InternalAccountingUnit
    const tasset = module.tasset as unknown as TAsset

    // update blacklister
    await tasset.updateBlacklister(deployer)

    //obtain some TAsset
    await iau.addMinter(u1)
    await iau.connect(u1).mintTo(u1, eth(100))
    await iau.connect(u1).approve(tasset, ethers.MaxUint256)
    await tasset.connect(u1).deposit(eth(100), u1)
    await iau.removeMinter(u1)

    return { iau, mockUnderlying, tasset, deployer, u1, u2, u3 }
  }

  it(`should deploy with correct underlying and asset`, async () => {
    const { tasset, iau, mockUnderlying } = await loadFixture(deployFixture)
    expect(await tasset.asset()).eq(iau)
    expect(await tasset.getUnderlying()).eq(mockUnderlying)
  })

  it(`_update() happy path`, async () => {
    const { tasset, u1, u2 } = await loadFixture(deployFixture)

    await expect(tasset.connect(u1).transfer(u2, eth(10))).not.reverted
  })

  it(`_update() should revert if _from blacklisted`, async () => {
    const { tasset, u1, u2 } = await loadFixture(deployFixture)

    await tasset.blacklist(u1)

    await expect(tasset.connect(u1).transfer(u2, eth(10))).revertedWithCustomError(tasset, `AccountBlacklisted`)

    await tasset.unBlacklist(u1)

    await expect(tasset.connect(u1).transfer(u2, eth(10))).not.reverted
  })

  it(`_update() should revert if _to blacklisted`, async () => {
    const { tasset, u1, u2 } = await loadFixture(deployFixture)

    await tasset.blacklist(u2)

    await expect(tasset.connect(u1).transfer(u2, eth(10))).revertedWithCustomError(tasset, `AccountBlacklisted`)

    await tasset.unBlacklist(u2)

    await expect(tasset.connect(u1).transfer(u2, eth(10))).not.reverted
  })

  it(`_update() should revert if msg.sender blacklisted`, async () => {
    const { tasset, deployer, u1, u2 } = await loadFixture(deployFixture)

    await tasset.connect(u1).approve(deployer, ethers.MaxUint256)

    await expect(tasset.transferFrom(u1, u2, eth(10))).not.reverted

    await tasset.blacklist(deployer)

    await expect(tasset.transferFrom(u1, u2, eth(10))).revertedWithCustomError(tasset, `AccountBlacklisted`)
  })

  it(`should revert if non-minter address redeems TAsset`, async () => {
    const { tasset, u1, iau } = await loadFixture(deployFixture)
    await expect(tasset.connect(u1).redeem(eth(1), u1, u1)).revertedWithCustomError(tasset, `Unauthorized`)
    await iau.addMinter(u1)
    await expect(tasset.connect(u1).redeem(eth(1), u1, u1)).not.reverted
  })
})
