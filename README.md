## Foundry hackathon experience inspired starter

Deleting things is easier than installing them, so this starter goal is to be bulky but cover most potential projects

## Installed libraries

* Solmate
* Open Zeppelin contracts

## Mocks

* ERC20: public mint, burn, permit
* ERC721: enumerable, public mint, burn

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
