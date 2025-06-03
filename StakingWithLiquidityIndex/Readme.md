# 🧱 Staking Contract with Real-Time Interest Accrual (aToken Model)

This is a modern Solidity-based staking contract that uses a scalable balance system inspired by Aave’s aToken mechanism. It supports real-time interest accrual through liquidity indexes, multiple supported ERC20 tokens, and automatic interest calculation with reserve factor logic.

---

## 🚀 Features

- ✅ Stake multiple ERC20 tokens (configurable)
- ✅ Real-time compound interest using liquidity index
- ✅ Earn yield via `APY`, auto-applied every block
- ✅ Scalable balance system (aToken-style)
- ✅ Interest share split between user and reserve (via `reserveFactor`)
- ✅ Modular & gas-efficient design
- ✅ Uses `aToken` wrappers for accounting

---

## 📦 Contracts

- `Staking.sol` — Main staking logic, index-based compounding
- `IaToken` — Interface for minting/burning wrapped yield tokens
- Compatible with custom ERC20 tokens like `aETH`, `aBTC`, etc.

---

## 🧠 How It Works

- On `deposit`:
  - Updates liquidity index
  - Mints scaled aTokens to user
  - Transfers base tokens to staking contract
- On `withdraw`:
  - Burns scaled aTokens
  - Returns principal + earned interest (minus reserve cut)
- Interest compounds over time using a per-second APY model.

---

## 🛠️ Configuration

- `APY` — Annual yield in percentage (e.g. 7 = 7% per year)
- `reserveFac
