# Numoen Manager

Contracts for managing Numoen perpetual options positions.

## Deployments

`LiquidityManager` has been deployed to `0x7F5B1B07b91Ac3853891E6837143F77F38466D78` and `LendgineRouter` has been deployed to `0xE9c7FD75768c1104440590607bdCE5a7Be05333A` on the following networks:

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
