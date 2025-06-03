# 💎 DiamondHands

**DiamondHands** is a minimal ETH staking contract designed for long-term holders. Once deposited, your ETH is locked for **2 years** (`63072000 seconds`). The longer you HODL, the stronger your diamond hands shine.

---

## 🔐 Features

- ⛓️ **2-Year Lock**: ETH deposits are locked for exactly 2 years from deposit.
- 🧠 **Weighted Unlock Time**: Multiple deposits average the unlock time based on deposit size.
- 🧾 **Fallback + Receive**: Direct transfers also lock ETH.
- 📤 **Withdrawal**: Withdraw only after lock expires.
- 🧯 **SelfDestruct**: Owner can destroy the contract and recover remaining funds.
- ⚠️ Gas-efficient custom errors.

---

## 🧪 Functions

### User

- `deposit() external payable`  
  Deposits ETH (≥ `0.0001 ether`) and locks it for 2 years.

- `withdraw() external`  
  Withdraws your ETH after unlock time. Reverts if still locked or zero balance.

- `getRemainingTime() external view returns (uint)`  
  Shows seconds left until funds unlock. Reverts if already unlocked.

- `getBalance() external view returns (uint)`  
  Returns your current ETH locked balance.

### Owner

- `SelfDestruct() external onlyOwner`  
  Transfers remaining ETH to the owner and renounces ownership.

---

## 🧠 Lock Calculation

New deposits update unlock time using weighted average:

```solidity
unlockTime = (oldAmount * oldUnlock + newAmount * (block.timestamp + 2 years)) / (oldAmount + newAmount);
```

---

## ❌ Errors

| Error                   | When it Happens                             |
|------------------------|---------------------------------------------|
| `InvalidAmount()`       | If deposit < `0.0001 ether`                 |
| `InsufficientBalance()` | On withdraw with 0 balance                  |
| `StillLocked()`         | Withdraw before unlock time                 |
| `FundsUnlocked()`       | Calling `getRemainingTime()` after unlock  |

---

## 📦 Deployment

```bash
forge create --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> src/DiamondHands.sol:DiamondHands --constructor-args <owner_address>
```

---

## 📜 License

MIT
