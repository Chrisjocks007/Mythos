# 🛡️ Mythos - Guild Alliance Protocol

**Mythos** is a fantasy-themed coordination smart contract enabling gaming guilds to form alliances, embark on epic multi-guild quests, vote on participation, pledge resources, and receive rewards for completing legendary missions.

---

## 🌟 Key Features

- **Guild Registration**: Register structured gaming guilds with leadership, member thresholds, and treasury ownership.
- **Epic Quest Creation**: Guild masters can summon quests that require strategic alliance across multiple guilds.
- **Decentralized Voting**: Individual warriors vote on whether to join or decline quests, weighted by combat power.
- **Participation Tracking**: Smart consensus formation per guild based on participation and power thresholds.
- **Treasure Pledging & Distribution**: Guilds can lock treasures for quests and earn fair rewards post-successful completion.
- **Campaign Management** *(stub-ready)*: Framework for multi-quest campaigns with status tracking.

---

## 📜 Data Structures

### 🏰 `gaming-guilds`
Stores guild metadata including:
- `guild-name`, `leadership-token`, `member-threshold`, `guild-treasury`, `is-active`

### 📖 `epic-quests`
Defines quests with:
- `quest-name`, `quest-lore`, `quest-giver`, `allied-guilds`, `treasure-split`, timing, and difficulty.

### ⚔️ `guild-participation`
Tracks each guild’s stance:
- Members committed/opposed, consensus status, total combat power.

### 🧙 `member-decisions`
Tracks individual warrior votes per quest:
- Decision, power, timestamp.

### 💰 `treasure-commitments`
Handles gold pledges and unlocking conditions tied to quest status.

### 🏹 `alliance-campaigns` *(optional expansion)*
Support for chaining quests into larger campaign narratives.

---

## ⚙️ Public Functions

| Function | Description |
|---------|-------------|
| `forge-guild-alliance` | Registers a new guild |
| `summon-epic-quest` | Creates a multi-guild quest |
| `make-warrior-decision` | Warrior votes on participation |
| `complete-epic-quest` | Marks quest complete and distributes rewards |
| `pledge-guild-treasure` | Locks guild funds toward a quest |

---

## 🔍 Read-only Queries

- `get-quest-details`
- `get-guild-info`
- `get-guild-quest-status`
- `get-warrior-decision`
- `can-warrior-decide`

---

## ❌ Error Codes

| Code | Meaning |
|------|---------|
| `u200` | Master-only action |
| `u201` | Not a guild member |
| `u202` | Invalid quest |
| `u203` | Quest expired |
| `u204` | Already voted |
| `u205` | Insufficient participation |
| `u206` | Quest not completed |
| `u207` | Guild not found |
| `u208` | Invalid treasure entry |

---

## 🔮 Future Enhancements

- **Dynamic difficulty-based reward scaling**
- **Reputation tracking for warriors**
- **NFT loot integration**
- **Inter-guild diplomacy and betrayal mechanics**
- **On-chain storytelling for quests and campaigns**

---

## 🧩 Contract Summary

- **Language**: Clarity
- **Protocol Theme**: Fantasy RPG / Multi-guild cooperation
- **Fee Structure**: 0.5 STX for quest initiation
- **Consensus Mechanism**: Weighted voting by combat power

---

## 🛠️ Deploy & Use

1. Deploy contract as `mythos`
2. Use `forge-guild-alliance` to register guilds
3. Initiate `summon-epic-quest` to launch quests
4. Track, vote, and complete quests
