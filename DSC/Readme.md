# DSCEngine: Decentralized StableCoin Engine

**Author**: Gakarot
**License**: MIT
**Solidity Version**: 0.8.19

---

## 🏋️ Overview

DSCEngine is the core contract of a decentralized stablecoin (DSC) system that:

* Maintains a **1 DSC = \$1** peg.
* Uses **WETH** and **WBTC** as **exogenous collateral**.
* Provides **no governance**, **no fees**, and is **minimally designed**.

The design is loosely inspired by MakerDAO (DAI) but far more simplified and automated.

---

## 🪙 Key Properties

* **Exogenous Collateral**: Only WETH/WBTC-backed.
* **Overcollateralized**: Requires 200% collateral ratio.
* **Health Factor-Based Liquidation**
* **No Governance / No Stability Fees**
* **Fixed 10% Liquidation Bonus (with fallback cases)**

---

## ⚖️ Core Concepts

### Collateral Requirements:

* Liquidation Threshold = 50% (i.e., you must be 200% overcollateralized).
* Min Health Factor = `1.1e18`

### Liquidation Bonus:

* 10% bonus if collateral is sufficient
* Partial bonus or 0.5% incentive in edge cases

---

## 📃 Contract Structure

### Imports

* OpenZeppelin's `ReentrancyGuard`, `Ownable`, and `IERC20`
* Chainlink Price Feeds (`AggregatorV3Interface`)

### Key State Variables

* `s_priceFeeds`: Token => Price Feed
* `s_collateralDeposited`: User => Token => Amount
* `s_DSCMinted`: User => Amount
* `s_collateralTokens`: List of allowed tokens (e.g., WETH/WBTC)
* `i_Dsc`: Stablecoin instance (DecentralizedStableCoin)

---

## 🚀 External Functions

### `depositCollateralAndMintDsc()`

Deposits collateral and mints DSC in a single transaction.

### `redeemCollateralForDsc()`

Burns DSC and returns underlying collateral.

### `redeemCollateral()`

Withdraws collateral directly (checks health factor).

### `burnDsc()`

Burns DSC from caller and checks health factor.

### `liquidate()`

Allows liquidators to seize collateral if a user’s health factor falls below 1.1.

* Handles partial and full liquidation.
* Applies bonuses appropriately.

### `withdrawProtocolCollateral()`

Allows owner to withdraw protocol-level collateral.

---

## 🛡️ Internal Mechanics

### `_revertIfHealthFactorIsBroken()`

Validates if user's position is safe.

### `_burnDsc()` / `_mint()`

Low-level logic to mint or burn DSC tokens.

### `_seizeUserCollateral()`

Handles liquidation collateral transfer logic.

### `_getUsdValue()`

Gets USD value of a token amount using Chainlink price feed.

### `_calculateHealthFactor()`

Returns health factor (higher is safer).

---

## 🪧 View & Utility Functions

* `getHealthFactor(address)`
* `getAccountCollateralValue(address)`
* `getCollateralBalanceOfUser(user, token)`
* `getUsdValue(token, amount)`
* `getTokenAmountFromUsd(token, usdAmount)`
* `getCollateralTokenPriceFeed(token)`
* `getCollateralTokens()`
* `getDsc()`

---

## 🌍 Liquidation Scenarios

| Scenario                       | Description              | Bonus         |
| ------------------------------ | ------------------------ | ------------- |
| Collateral covers debt + bonus | Full liquidation         | 10%           |
| Collateral covers debt only    | Partial liquidation      | Partial Bonus |
| Collateral < debt              | Burn as much as possible | 0.5%          |

---

## ❌ Reverts & Errors

* `DSCEngine_NeedsMoreThanZero()`
* `DSCEngine__TokenNotAllowed()`
* `DSCEngine_BreaksHealthFactor()`
* `DSCEngine_MintFailed()`
* `DSCEngine_healthFactorOk()`
* `DSCEngine_HealthFactorNotImproved()`
* `DSCEngine_LiquidatorDscBalanceLow()`
* `DSCEngine_InsufficientCollateral()`

---

## 📊 Constants

| Name                    | Value  | Meaning                             |
| ----------------------- | ------ | ----------------------------------- |
| `LIQUIDATION_THRESHOLD` | 50     | 200% overcollateralization required |
| `LIQUIDATION_PRECISION` | 100    | Precision basis for bonus/threshold |
| `PRECISION`             | 1e18   | Scaling factor for decimals         |
| `MIN_HEALTH_FACTOR`     | 1.1e18 | Minimum safety factor               |
| `LIQUIDATION_BONUS`     | 10     | 10% reward to liquidator            |

---

## 🚀 Usage Flow

### Deposit & Mint

1. User deposits WETH/WBTC as collateral.
2. Mints DSC against collateral.
3. Must stay above health factor 1.1.

### Burn & Redeem

1. Burn DSC tokens.
2. Redeem underlying collateral.
3. Health factor is checked post-redeem.

### Liquidation

1. Anyone can call `liquidate(user, debtToCover)`.
2. If user health factor < 1.1:

   * DSC is burned from liquidator.
   * Collateral is seized from user.
   * Bonus is rewarded.

---

## 🌊 Invariant Ideas

* Total DSC minted ≤ total collateral value.
* Collateral deposited must always be > 0.
* Health factor must always be > 1.1 post ops.

---

## 🚑 Test Suggestions

* Unit test all edge cases (zero amounts, reverts, etc.)
* Integration tests for deposit-mint-burn-redeem
* Invariant testing for health factor, collateral > 0

---

## ✨ Future Ideas

* Add protocol fee for minting or redemption.
* Support for more assets (ETH, stETH, etc).
* Integrate flash loan-based liquidation.

---

## 🚧 Disclaimer

This is a simplified, learning-oriented implementation of a stablecoin engine. It is not production-ready.

---

## 📁 Files

* `DSCEngine.sol` - Core protocol logic
* `DecentralizedStableCoin.sol` - ERC20-like token contract
* `ERC20Mock.sol` - For local testing
* `Test` & `Handler` - For Foundry tests (unit, fuzz, invariant)

---

Happy Hacking ✨
**Gakarot Out.** 🕵️‍♂️
