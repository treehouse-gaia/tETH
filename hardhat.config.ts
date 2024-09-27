import 'dotenv/config'
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
  solidity: {
    version: `0.8.24`,
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000
      },
      evmVersion: `cancun`
    }
  },
  ignition: {
    requiredConfirmations: 1
  },
  networks: {
    hardhat: {
      forking: {
        enabled: true,
        blockNumber: 20244408,
        url: `https://cloudflare-eth.com`
      }
    }
  },
  gasReporter: {
    enabled: false
  }
}

export default config
