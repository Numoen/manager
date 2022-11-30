# Numoen Manager

Contracts for managing Numoen perpetual options positions.

## Deployments

`LiquidityManager` has been deployed to `0x82d4D8a3609F8C5d19b59339A75E2a25AfC3e564` and `LendgineRouter` has been deployed to `0x0a0E6120228f521f38b16dD12aA6CD859c307bC4` on the following networks:

- Ethereum Goerli Testnet

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
