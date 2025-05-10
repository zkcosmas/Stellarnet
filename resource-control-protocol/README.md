# 🌌 Stellarnet

**Stellarnet** is a decentralized platform for interstellar resource registration, trading, and extraction. It empowers cosmic explorers to tokenize their discoveries, manage extraction rights, and receive credit-based compensation — all tracked immutably on-chain.

---

## 🚀 Features

- **Resource Registration:** Explorers can register newly discovered cosmic resources, with metadata including mass, spatial coordinates, elemental composition, and rarity.
- **Extraction Rights Claiming:** Users can claim extraction rights if they have sufficient credits and the resource is available.
- **Stability Period Enforcement:** Prevents extraction until a specified number of blocks have passed since rights were claimed.
- **Reputation Indexing:** Discoverers earn reputation after successful extractions based on their registered resources.
- **Credits System:** All transactions and access rights are governed through a built-in credit system.
- **Decommissioning Resources:** Discoverers retain the authority to decommission resources before they're claimed.
- **Public Queries:** Anyone can inspect resource data, explorer credit balances, reputations, and discovery lists.

---

## 🛠 Contract Architecture

- **Maps:**
  - `cosmic-resource-registry`: Stores metadata and lifecycle status of each registered resource.
  - `credit-repository`: Tracks user balances in system credits.
  - `explorer-reputation-index`: Tracks reputation points per discoverer.
  - `explorer-discovery-registry`: Lists recent discoveries by each explorer.

- **Key Functions:**
  - `register-cosmic-discovery`: Registers a new resource.
  - `claim-extraction-rights`: Transfers rights to extract based on credits and availability.
  - `complete-extraction`: Finalizes extraction and transfers bonuses to discoverer.
  - `deposit-credits`: Adds credits to a user's account.
  - `decommission-resource`: Allows discoverers to mark resources as unavailable.

- **Read-only Interfaces:**
  - `query-resource-data`
  - `check-explorer-balance`
  - `get-explorer-reputation`
  - `list-discovered-resources`
  - `calculate-rarity-multiplier`

