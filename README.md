# Personal-Finance-Coach

Automated budgeting, savings goals, and debt payoff plans built on Stacks with Clarity smart contracts. This project contains two independent contracts designed to work side-by-side without cross-contract calls:

- aggregation-adapter: Bank connection and transaction normalization
- advice-engine: Rules for goals, alerts, and recommendations

Overview

This system lets users:
- Register banks and open accounts (logical identifiers only)
- Record and normalize transactions into a standardized structure
- Create savings goals, contribute toward them, and receive simple progress-based advice

Design goals

- Simplicity first: only the logic needed for core features
- Clean, readable Clarity with clear errors and explicit access checks
- No cross-contract calls or traits as required
- Deterministic data layout using data-vars and maps

Contracts

1) aggregation-adapter
- Bank registry with sequential IDs
- Account management per principal, with currency and labels
- Transaction recording (amount, timestamp, merchant, category) with a normalized flag
- Normalization is a simple validation pass that marks a transaction normalized when certain conditions are satisfied (no empty category, non-zero amount)
- Read-only getters for banks, accounts, and transactions

2) advice-engine
- Savings goals per principal with target amount, current amount, deadline
- Contributions increase current progress
- Advice generation classifies a goal as: reached, behind schedule, or on track (based on progress and a simple time threshold)
- Read-only getters and progress helpers (no dynamic string formatting to keep on-chain logic deterministic and simple)

Local development

Prerequisites (already installed in this environment):
- Git
- GitHub CLI (gh)
- Clarinet

Common commands

- clarinet check
  Compile and type-check all contracts

- clarinet console
  Launch a REPL for experimenting with contracts (read-only)

- clarinet test
  Run tests (you can add Vitest/Typescript tests under tests/)

Project structure

- Clarinet.toml: Clarinet configuration for the project
- contracts/: Clarity source files (.clar)
- settings/: Clarinet network settings
- tests/: Test suites scaffolded by Clarinet
- .vscode/: Developer experience helpers

Branching strategy

- main: Project initialization and documentation only
- development: Active contract development (contracts/, tests/)

Security and constraints

- No cross-contract calls or trait usage
- Simple, clear authorization rules: only the owner can mutate their own resources
- Designed as example logic; review carefully before using on mainnet

License

MIT
