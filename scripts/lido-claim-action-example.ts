import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import { setBalance } from '@nomicfoundation/hardhat-network-helpers'
import ActionModule from '../ignition/modules/Action'
import StrategyModule from '../ignition/modules/Strategy'
import { ERC20, LidoWithdrawClaim, StrategyExecutor, StrategyStorage } from '../typechain-types'
import { eth, impersonateAndRun } from './utils'
import { CONSTANTS } from '../ignition/constants'

async function main() {
  const encoder = new ethers.AbiCoder()
  const [deployer] = await ethers.getSigners()
  const UNSTETH_MAINNET = CONSTANTS.UNSTETH
  const WETH_MAINNET = CONSTANTS.WETH

  const c_weth = await ethers.getContractAt(`ERC20`, WETH_MAINNET)
  const c_unsteth_nft = await ethers.getContractAt(
    [`function transferFrom(address,address,uint) external`, `function ownerOf(uint) external view returns (address)`],
    UNSTETH_MAINNET
  )
  const c_unsteth = await ethers.getContractAt(`IUnStEth`, UNSTETH_MAINNET)
  const { strategyExecutor, strategyStorage } = await ignition.deploy(StrategyModule)

  // @ts-ignore
  const { lidoWithdrawClaim }: { lidoWithdrawClaim: LidoWithdrawClaim } = await ignition.deploy(ActionModule)
  const _strategyExecutor = strategyExecutor as unknown as StrategyExecutor
  const _strategyStorage = strategyStorage as unknown as StrategyStorage

  const _strategy = await ethers.getContractAt(`Strategy`, await _strategyStorage.getStrategyAddress(0))
  const stratAddress = await _strategy.getAddress()
  const printBalanceOfStratAddress = printBalanceOf(stratAddress)

  // block 20158098
  const NFT_OWNER = `0x85B78AcA6Deae198fBF201c82DAF6Ca21942acc6`
  const UNCLAIMED_NFT = 43171
  const HINT = 404
  const STRATEGY_ID = 0
  await setBalance(NFT_OWNER, eth(1))

  // add deployer as executor
  await _strategyExecutor.updateExecutor(deployer, true)

  // transfer nft to strat
  if ((await c_unsteth_nft.ownerOf(UNCLAIMED_NFT)) != stratAddress) {
    await impersonateAndRun(NFT_OWNER, async (signer) => {
      //@ts-ignore
      await c_unsteth_nft.connect(signer).transferFrom(NFT_OWNER, stratAddress, UNCLAIMED_NFT)
      console.log(`transferred nft:`, await c_unsteth_nft.ownerOf(UNCLAIMED_NFT))
    })
  }

  const [expected] = await c_unsteth.getWithdrawalStatus([UNCLAIMED_NFT])
  printBalanceOfStratAddress(c_weth) // should be 0

  const lwc = await lidoWithdrawClaim.getId()
  if (!(await _strategyStorage.isActionWhitelisted(stratAddress, lwc))) {
    console.log(`whitelisting actions`)
    await _strategyStorage.whitelistActions(STRATEGY_ID, [lwc])
  }
  // claim nft
  const lidoNftClaimCd = encoder.encode([`tuple(uint[],uint[])`], [[[UNCLAIMED_NFT], [HINT]]])
  await _strategyExecutor.executeOnStrategy(STRATEGY_ID, [lwc], [lidoNftClaimCd], [[]])

  printBalanceOfStratAddress(c_weth) // should be > 0

  expect(await c_weth.balanceOf(stratAddress)).eq(expected.amountOfStETH)
}

const printBalanceOf = (address: string) => async (token: ERC20) => {
  const symbol = await token.symbol()
  const val = await token.balanceOf(address)
  console.log(`${address.slice(-4)} ${symbol}\t`, ethers.formatEther(val))

  return val
}

main().catch((e) => {
  console.log(e)
  process.exit(1)
})
