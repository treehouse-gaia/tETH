import { ethers } from 'hardhat'

/**
 * Returns the bytes4 actionId of an action contract
 *
 * @param name name of contract E.g. LidoStake
 * @returns bytes4 action id E.g. 0xd7e40b2d
 */
export const getActionIdFromName = (name: string) => ethers.solidityPackedKeccak256([`string`], [name]).slice(0, 10)

export function camelcase(str: string) {
  return str.charAt(0).toLowerCase() + str.slice(1)
}
