import { ethers } from 'hardhat'
import { impersonateAccount, stopImpersonatingAccount } from '@nomicfoundation/hardhat-network-helpers'

export const eth = (amt: string | number) => ethers.parseEther(`${amt}`)

export const sleep = (seconds: number) => new Promise((resolve) => setTimeout(resolve, seconds * 1000))

export const impersonateAndRun = async (
  address: string,
  fn: (signer: Awaited<ReturnType<typeof ethers.getSigner>>) => Promise<void>,
  options?: { noLogs?: boolean }
) => {
  await impersonateAccount(address)
  if (!options?.noLogs) {
    console.log(`Impersonating ${address}...`)
  }
  const deployer = await ethers.getSigner(address)

  await fn(deployer)

  await stopImpersonatingAccount(address)
  if (!options?.noLogs) {
    console.log(`Stopped impersonating`)
  }
}

export const getEncodedCalldata = async (
  iface: string[],
  fnName: string,
  params: (string | number | bigint)[]
): Promise<string> => {
  // const ifaceERC20 = new ethers.Interface([
  //   `function approve(address spender, uint256 amount)`,
  //   `function transfer(address to, uint256 amount)`
  // ])
  // return _iface.encodeFunctionData(`approve`, [SpenderContractAddress, 1000])

  const _iface = new ethers.Interface(iface)
  return _iface.encodeFunctionData(fnName, params)
}
