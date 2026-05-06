# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm install          # Install dependencies
npm run compile      # Compile contracts (hardhat compile)
npm test             # Run all tests
npm run deploy       # Deploy to local hardhat network
npm run deploy:sepolia  # Deploy to Sepolia testnet
```

Run a single test file:
```bash
npx hardhat test test/GL1PolicyWrapper.test.js
npx hardhat test test/FXConversion.test.js
npx hardhat test test/ERC3643.test.js
```

## Project Overview

**GL1 Programmable Compliance Toolkit** — a Solidity smart contract framework implementing embedded supervisory architecture for regulated cross-border financial transactions. The system enforces real-time compliance rules (KYC/AML, FX limits, capital controls, collateral checks) on-chain.

**Solidity 0.8.20 | Hardhat | OpenZeppelin v5 | Optimizer enabled (200 runs, via IR)**

## Architecture

### Core Execution Layer (`contracts/core/`)

- **GL1PolicyWrapper.sol** — Entry point for all asset operations. Orchestrates wrap/unwrap and FX conversion. Routes compliance checks through GL1PolicyManager.
- **GL1PolicyManager.sol** — Policy engine. Coordinates identity verification (via CCID) and executes the full compliance rule chain before authorizing any transaction.
- **RepoContract.sol** — Atomic repurchase agreement settlement. Locks collateral, enforces LTV, and handles maturity/default.
- **FXRateProvider.sol** — On-chain FX rates for TWD, SGD, USD, CNY.
- **CCIDRegistry.sol** — Cross-chain identity registry mapping wallet addresses to verified CCID identifiers.
- **STRRepository.sol** — Settlement Transaction Repository; records finalized transactions for audit.

### Compliance Rules (`contracts/rules/`)

Each rule implements `IComplianceRule` and is independently deployable. GL1PolicyManager executes them in sequence:

| Rule | Purpose |
|------|---------|
| `WhitelistRule` | KYC/AML — only whitelisted addresses may transact |
| `CashAdequacyRule` | Verifies lender balance is sufficient |
| `CollateralRule` | LTV and collateral value enforcement |
| `FXLimitRule` | Per-transaction and daily FX caps |
| `AMLThresholdRule` | Large transaction reporting and risk scoring |

### Token Standards (`contracts/token/`)

- **PBMToken.sol** — Purpose Bound Money using ERC-1155 + ERC-7943 (uRWA). Supports freeze and forced transfer for regulator override.
- **ERC3643Token.sol** — Security token using ERC-20 + ERC-3643 (T-REX standard). Enforces identity-linked transfer restrictions.

### ERC-3643 Modules (`contracts/erc3643/`)

Implements the T-REX compliance stack: `IdentityRegistry`, `TrustedIssuersRegistry`, `ClaimTopicsRegistry`, `ComplianceModule`.

### Integration (`contracts/integration/`)

- **ChainlinkACEIntegration.sol** — Verifies compliance state across chains via Chainlink ACE oracle.

## Transaction Flow

1. User calls GL1PolicyWrapper → validates jurisdiction, triggers CCID lookup
2. PolicyWrapper delegates to GL1PolicyManager → runs all IComplianceRule checks
3. If FX conversion required → FXRateProvider fetches rate → conversion applied
4. For repo transactions → RepoContract handles atomic collateral lock + settlement
5. ERC-7943 / ERC-3643 token transfers enforced at token layer
6. STRRepository records finalized transaction for audit trail

## Key Design Patterns

- **Modular rules**: Rules are plug-in; add/remove per jurisdiction without redeploying core.
- **Dual-standard compliance**: Asset layer uses ERC-3643 (identity-linked); transaction layer uses PBM (purpose-bound). Both must pass.
- **Jurisdiction-scoped policies**: Deployment script (`scripts/deploy.js`) configures separate rule sets per jurisdiction (TW, SG, EU).
- **Regulatory override**: ERC-7943 freeze/forced-transfer gives regulators direct asset control independent of normal transfer logic.
