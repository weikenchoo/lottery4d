## Lottery 4D
This is a decentralized 4D lottery, where random 4 digit numbers will be picked using Chainlink's VRF.  Players are able to submit numbers from 0 - 9999, and if the number matches the prize number, the player will receive a prize according to the prize pool. A countdown of 24 hours will be initiated to pick the prize numbers will when the first player submits a number.

### Distribution of prize:
First Prize : 70% of total prize pool

Second Prize : 20% of total prize pool

Third Prize : 10% of total prize pool

[Live Demo](https://lottery4d-frontend.vercel.app/)


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
