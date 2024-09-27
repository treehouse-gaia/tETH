import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { eth } from '../../scripts/utils'

// TODO
describe(`ActionExecutor`, function () {
  async function deployFixture() {
    const [deployer] = await ethers.getSigners()

    const mockAR = await (await ethers.getContractFactory(`MockActionRegistry`)).deploy()
    const mockAction = await (await ethers.getContractFactory(`MockAction`)).deploy()

    const actionExecutor = await (await ethers.getContractFactory(`ActionExecutor`)).deploy(mockAR)

    return { mockAction, actionExecutor, mockAR }
  }

  it(`executeActions() should revert if action not found`, async () => {
    const { actionExecutor } = await loadFixture(deployFixture)

    await expect(actionExecutor.executeActions([`0x11111111`], [`0x0000`], [[0, 0]]))
      .revertedWithCustomError(actionExecutor, `ActionIdNotFound`)
      .withArgs(`0x11111111`)
  })

  it(`executeActions() happy path`, async () => {
    const { actionExecutor, mockAR, mockAction } = await loadFixture(deployFixture)

    await mockAR.setAddr(mockAction)
    const encoder = new ethers.AbiCoder()
    const mockActionCd = encoder.encode([`uint`, `address`], [eth(0.5), await mockAR.getAddress()])

    await expect(actionExecutor.executeActions([await mockAction.getId()], [mockActionCd], [[0, 0]])).not.reverted
  })
})
