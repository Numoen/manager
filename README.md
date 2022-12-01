# Numoen Manager

Contracts for managing Numoen perpetual options positions.

## Deployments

`LiquidityManager` has been deployed to `0x0d9A2Eb3CBe96deeF3d6d62c5f3B620d5021941a` and `LendgineRouter` has been deployed to `0x27972ad7875BC17ADA5922C80db45B015DD554Df` on the following networks:

- Ethereum Goerli Testnet
- Arbitrum Mainnet

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```bash
forge install numoen/manager
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Test

```bash
forge test -f goerli
```

### Deployment

Make sure that the network is defined in foundry.toml, and dependency addresses updated in `Deploy.s.sol` then run:

```bash
sh deploy.sh [network]
```
