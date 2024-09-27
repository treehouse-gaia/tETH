import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe(`ActionRegistry`, function () {
  async function deployFixture() {
    const [deployer, u2] = await ethers.getSigners()
    const actionRegistry = await (await ethers.getContractFactory(`ActionRegistry`)).deploy(deployer)

    const lidoStakeAction = await (await ethers.getContractFactory(`LidoStake`)).deploy()
    const newLidoStakeAction = await (await ethers.getContractFactory(`LidoStake`)).deploy()
    const lidoStakeActionId = await lidoStakeAction.getId()

    return { actionRegistry, lidoStakeAction, newLidoStakeAction, lidoStakeActionId, u2 }
  }

  describe(`addNewContract()`, async () => {
    it(`revert if not owner`, async () => {
      const { actionRegistry, lidoStakeAction, lidoStakeActionId, u2 } = await loadFixture(deployFixture)

      await expect(
        actionRegistry.connect(u2).addNewContract(lidoStakeActionId, lidoStakeAction)
      ).revertedWithCustomError(actionRegistry, `OwnableUnauthorizedAccount`)
    })

    it(`revert if already exist`, async () => {
      const { actionRegistry, lidoStakeAction, lidoStakeActionId } = await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await expect(actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)).revertedWithCustomError(
        actionRegistry,
        `EntryAlreadyExistsError`
      )
    })

    it(`happy path`, async () => {
      const { actionRegistry, lidoStakeAction, lidoStakeActionId } = await loadFixture(deployFixture)

      await expect(actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction))
        .emit(actionRegistry, `AddNewContract`)
        .withArgs(lidoStakeActionId, lidoStakeAction)

      expect(await actionRegistry.isRegistered(lidoStakeActionId)).eq(true)

      expect(await actionRegistry.getAddr(lidoStakeActionId)).eq(lidoStakeAction)
    })
  })

  describe(`revertToPreviousAddress()`, async () => {
    it(`revert if not owner`, async () => {
      const { actionRegistry, lidoStakeActionId, u2 } = await loadFixture(deployFixture)

      await expect(actionRegistry.connect(u2).revertToPreviousAddress(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`revert if not exist`, async () => {
      const { actionRegistry, lidoStakeActionId } = await loadFixture(deployFixture)

      await expect(actionRegistry.revertToPreviousAddress(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EntryNonExistentError`
      )
    })

    it(`revert if already exist`, async () => {
      const { actionRegistry, lidoStakeAction, lidoStakeActionId } = await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await expect(actionRegistry.revertToPreviousAddress(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EmptyPrevAddrError`
      )
    })

    it(`happy path`, async () => {
      const [deployer] = await ethers.getSigners()
      const { actionRegistry, lidoStakeAction, newLidoStakeAction, lidoStakeActionId } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)
      await actionRegistry.approveContractChange(lidoStakeActionId)

      expect(await actionRegistry.getAddr(lidoStakeActionId)).eq(newLidoStakeAction)

      await expect(actionRegistry.revertToPreviousAddress(lidoStakeActionId))
        .emit(actionRegistry, `RevertToPreviousAddress`)
        .withArgs(deployer, lidoStakeActionId, newLidoStakeAction, lidoStakeAction)

      expect(await actionRegistry.getAddr(lidoStakeActionId)).eq(lidoStakeAction)
    })
  })

  describe(`startContractChange()`, async () => {
    it(`revert if not owner`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction, u2 } = await loadFixture(deployFixture)

      await expect(
        actionRegistry.connect(u2).startContractChange(lidoStakeActionId, lidoStakeAction)
      ).revertedWithCustomError(actionRegistry, `OwnableUnauthorizedAccount`)
    })

    it(`revert if not exist`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction } = await loadFixture(deployFixture)

      await expect(actionRegistry.startContractChange(lidoStakeActionId, lidoStakeAction)).revertedWithCustomError(
        actionRegistry,
        `EntryNonExistentError`
      )
    })

    it(`happy path`, async () => {
      const { actionRegistry, newLidoStakeAction, lidoStakeActionId, lidoStakeAction } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)

      await expect(actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)).emit(
        actionRegistry,
        `StartContractChange`
      )
    })
  })

  describe(`approveContractChange()`, async () => {
    it(`revert if not owner`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction, newLidoStakeAction, u2 } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)

      await expect(actionRegistry.connect(u2).approveContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`revert if not exist`, async () => {
      const { actionRegistry, lidoStakeActionId } = await loadFixture(deployFixture)

      await expect(actionRegistry.approveContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EntryNonExistentError`
      )
    })

    it(`revert if not pending change`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction } = await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await expect(actionRegistry.approveContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EntryNotInChangeError`
      )
    })

    it(`happy path`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction, newLidoStakeAction } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)

      await expect(actionRegistry.approveContractChange(lidoStakeActionId)).emit(
        actionRegistry,
        `ApproveContractChange`
      )
    })
  })

  describe(`cancelContractChange()`, async () => {
    it(`revert if not owner`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction, newLidoStakeAction, u2 } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)

      await expect(actionRegistry.connect(u2).cancelContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `OwnableUnauthorizedAccount`
      )
    })

    it(`revert if not exist`, async () => {
      const { actionRegistry, lidoStakeActionId } = await loadFixture(deployFixture)

      await expect(actionRegistry.cancelContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EntryNonExistentError`
      )
    })

    it(`revert if not pending change`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction } = await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await expect(actionRegistry.cancelContractChange(lidoStakeActionId)).revertedWithCustomError(
        actionRegistry,
        `EntryNotInChangeError`
      )
    })

    it(`happy path`, async () => {
      const { actionRegistry, lidoStakeActionId, lidoStakeAction, newLidoStakeAction } =
        await loadFixture(deployFixture)

      await actionRegistry.addNewContract(lidoStakeActionId, lidoStakeAction)

      await actionRegistry.startContractChange(lidoStakeActionId, newLidoStakeAction)

      await expect(actionRegistry.cancelContractChange(lidoStakeActionId)).emit(actionRegistry, `CancelContractChange`)
    })
  })
})
