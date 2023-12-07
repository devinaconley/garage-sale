# garage-sale

protocol for easy tax-loss harvesting on low-value NFTs and bundled resale to auction

## setup

this repo uses [foundry](https://book.getfoundry.sh/) for development, testing, and deployment

## development

build contracts

```
forge build
```

run all tests

```
forge test
```

report gas usage
```
forge test --gas-report
```

compute test coverage
```
forge coverage
```

## deployment

copy `.env.template` to `.env` and define relevant fields


deploy to sepolia
```
forge script script/GarageSale.s.sol --ledger --hd-paths "m/44'/60'/<index>'/0/0" --sender "<0xdeployer>" --rpc-url <rpc_url> --broadcast
```

verify contract
```
forge verify-contract --chain-id 11155111 --num-of-optimizations 10000  <0xcontract> src/GarageSale.sol:GarageSale
```
