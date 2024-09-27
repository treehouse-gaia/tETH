import { loadFixture, setBalance } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { ethers } from 'hardhat'
import { expect } from 'chai'
import { eth } from '../../scripts/utils'

describe(`Rescuable`, () => {
  async function deployFixture() {
    const rescuable = await (await ethers.getContractFactory(`MockRescuable`)).deploy()

    // mint some mock token
    const mockToken = await (await ethers.getContractFactory(`MockErc20`)).deploy(`MOCK`, `MOCK`)

    await mockToken.mintTo(rescuable, eth(1))
    await setBalance(await rescuable.getAddress(), eth(1))

    return { rescuable, mockToken }
  }

  it(`should revert if rescuer not set by owner`, async () => {
    const [deployer, u1] = await ethers.getSigners()
    const { rescuable } = await loadFixture(deployFixture)
    await expect(rescuable.connect(u1).updateRescuer(deployer)).revertedWithCustomError(
      rescuable,
      `OwnableUnauthorizedAccount`
    )
  })

  it(`should revert if not rescuer`, async () => {
    const [deployer] = await ethers.getSigners()
    const { rescuable, mockToken } = await loadFixture(deployFixture)
    await expect(rescuable.rescueERC20(mockToken, deployer, eth(1))).reverted
  })

  it(`rescueERC20() happy path`, async () => {
    const [deployer] = await ethers.getSigners()
    const { rescuable, mockToken } = await loadFixture(deployFixture)

    // update rescuer
    await expect(rescuable.updateRescuer(deployer)).not.reverted

    await rescuable.rescueERC20(mockToken, deployer, eth(1))
    expect(await mockToken.balanceOf(deployer)).eq(eth(1))
    expect(await mockToken.balanceOf(rescuable)).eq(0)
  })

  it(`rescueETH() happy path`, async () => {
    const [deployer, u2] = await ethers.getSigners()
    const provider = deployer.provider
    const { rescuable } = await loadFixture(deployFixture)

    // update rescuer
    await expect(rescuable.updateRescuer(deployer)).not.reverted

    const before = await provider.getBalance(u2)
    await rescuable.rescueETH(u2)
    const after = await provider.getBalance(u2)
    expect(after).eq(before + eth(1))
  })
})
