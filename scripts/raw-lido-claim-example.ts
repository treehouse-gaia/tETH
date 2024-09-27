import { expect } from 'chai'
import { ethers } from 'hardhat'
import { setBalance } from '@nomicfoundation/hardhat-network-helpers'
import { eth, impersonateAndRun } from './utils'
import { CONSTANTS } from '../ignition/constants'

async function main() {
  const [deployer] = await ethers.getSigners()
  const provider = deployer.provider
  const c_unsteth = await ethers.getContractAt(`IUnStEth`, CONSTANTS.UNSTETH)

  // block 20158098
  const NFT_OWNER = `0x85B78AcA6Deae198fBF201c82DAF6Ca21942acc6`
  const UNCLAIMED_NFT = 43171
  const HINT = 404
  await setBalance(NFT_OWNER, eth(1))

  await impersonateAndRun(NFT_OWNER, async (signer) => {
    const [result] = await c_unsteth.getWithdrawalStatus([UNCLAIMED_NFT])
    console.log(`expected eth`, result.amountOfStETH)
    console.log(`before`, await provider.getBalance(NFT_OWNER))
    await c_unsteth.connect(signer).claimWithdrawals([UNCLAIMED_NFT], [HINT])
    console.log(`after`, await provider.getBalance(NFT_OWNER))

    /// we use lt because it will be slightly less due to paying for tx cost
    expect(await provider.getBalance(NFT_OWNER)).lt(eth(1) + result.amountOfStETH)
    console.log(`done`)
  })
}

main().catch((e) => {
  console.log(e)
  process.exit(1)
})
