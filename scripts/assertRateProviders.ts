import { expect } from 'chai'
import { ethers, ignition } from 'hardhat'
import RateProviderModule from '../ignition/modules/RateProvider'
import { CONSTANTS } from '../ignition/constants'

async function main() {
  const c_weth = await ethers.getContractAt(`ERC20`, CONSTANTS.WETH)
  const c_steth = await ethers.getContractAt(`ERC20`, CONSTANTS.STETH)
  const c_wsteth = await ethers.getContractAt(`IwstETH`, CONSTANTS.WSTETH)
  const { rpr, wstethRp, stethRp, usdEthRp } = await ignition.deploy(RateProviderModule)

  const c_wstethRp = await ethers.getContractAt(`WstETHRateProvider`, wstethRp)
  const c_stethRp = await ethers.getContractAt(`ChainlinkRateProvider`, stethRp)
  const c_usdEthRp = await ethers.getContractAt(`ChainlinkRateProvider`, usdEthRp)
  const c_rpr = await ethers.getContractAt(`RateProviderRegistry`, rpr)
  // console.log(await c_wsteth.stEthPerToken(), await c_wstethRp.getRateInStEth())
  // console.log(await c_stethRp.getRate(), await c_rpr.getRateInEth(c_steth))
  // console.log(await c_wstethRp.getRate(), await c_rpr.getRateInEth(c_wsteth))
  // console.log(await c_rpr.getRateInEth(c_weth))
  // console.log(await c_usdEthRp.getRate(), await c_rpr.getEthInUsd())

  expect(await c_wsteth.stEthPerToken()).eq(await c_wstethRp.getRateInStEth())
  expect(await c_stethRp.getRate()).eq(await c_rpr.getRateInEth(c_steth))
  expect(await c_wstethRp.getRate()).eq(await c_rpr.getRateInEth(c_wsteth))
  expect(await c_rpr.getRateInEth(c_weth)).eq(BigInt(1e18))
  expect(await c_rpr.getEthInUsd()).eq(await c_usdEthRp.getRate())
  console.log(`done`)
}

main().catch((e) => {
  console.log(e)
  process.exit(1)
})
