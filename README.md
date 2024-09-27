# treehouse-protocol

Treehouse protocol core contracts

## Tooling

- Solidity 0.8.24
- Openzeppelin contracts v5

## Unit Tests

```
# make sure forking off mainnet
npx hardhat test
```

## Local deployment

```
# run local node
npm run fork

npm run deployLocal
```

## Test scripts (after deploying local)

```
# sim a deposit of weth for tETH
npx hardhat run scripts/deposit-weth.ts --network localhost

# sim a portfolio management sequence [Vault.Pull, aaveV3.Supply, aaveV3.borrow]
npx hardhat run scripts/test-pm.ts --network localhost
```
