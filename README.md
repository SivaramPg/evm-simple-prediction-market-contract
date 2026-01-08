# Simple Binary Prediction Markets (EVM)

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)
![Foundry](https://img.shields.io/badge/Foundry-Tested-green)
![Coverage](https://img.shields.io/badge/Coverage-98%25-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

**Simple, educational prediction market smart contracts for EVM chains**

[Quick Start](#-quick-start) | [Documentation](#-documentation) | [Examples](#-usage-examples) | [Contributing](#-contributing)

</div>

---

> **DISCLAIMER: This project is for educational purposes only. These smart contracts are UNAUDITED and should NOT be used in production as-is. The authors are not responsible for any damages, losses, or liabilities that may arise from the use of this code. Always conduct your own security audits and due diligence before deploying any smart contracts to mainnet.**

---

## Overview

Simple Binary Prediction Markets is an open-source implementation of pot-based binary prediction markets. Unlike complex platforms like Polymarket that use token splitting and orderbooks, this implementation uses a simple, intuitive pot-based system where users bet on YES/NO outcomes.

### Key Features

- **Simple Pot-Based Model** - No token splitting, no orderbooks, just simple pools
- **Binary Markets** - YES/NO outcomes only
- **Manual Resolution** - Admin-controlled market resolution
- **Config Snapshot** - Market configuration locked at creation
- **Multi-Chain Support** - Ethereum, Base, Polygon, Arbitrum, Optimism, BSC
- **Well Tested** - 98%+ test coverage, gas optimized

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    Prediction Market                        │
├─────────────────────────────────────────────────────────────┤
│  Market Creation → Betting → Resolution → Claiming         │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│  │   YES    │    │   NO     │    │  Winner  │             │
│  │  Pool    │    │  Pool    │    │ Takes    │             │
│  │          │    │          │    │  All     │             │
│  └──────────┘    └──────────┘    └──────────┘             │
│       └──────────────┴───────────────┘                    │
│              Proportional Distribution                     │
└─────────────────────────────────────────────────────────────┘
```

### Payout Formula

```
Winner Payout = User Bet + (User Bet / Winning Pool) × Losing Pool
```

**Example:**
- YES Pool: 200 USDC (You: 100, Others: 100)
- NO Pool: 100 USDC
- YES wins
- Your payout: 100 + (100/200) × 100 = **150 USDC**

---

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/evm-simple-prediction-market-contract.git
cd evm-simple-prediction-market-contract

# Install dependencies
forge install

# Copy environment file
cp .env.example .env
# Edit .env with your configuration
```

### Build & Test

```bash
# Build contracts
forge build

# Run tests
forge test

# Run tests with verbosity
forge test -vvv

# Check coverage
forge coverage
```

### Deploy

```bash
# Deploy to Sepolia (with mock token)
forge script script/Deploy.s.sol \
  --rpc-url $ETHEREUM_SEPOLIA_RPC \
  --broadcast \
  --verify

# Deploy to Base Sepolia
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC \
  --broadcast \
  --verify
```

---

## Documentation

### Contract Architecture

```
src/
├── PredictionMarket.sol    # Main contract
├── interfaces/
│   └── IERC20.sol          # ERC20 interface
└── mocks/
    └── MockERC20.sol       # Mock token for testing
```

### Core Functions

| Function | Access | Description |
|----------|--------|-------------|
| `createMarket` | Public | Create a new prediction market |
| `placeBet` | Public | Place a bet on YES or NO |
| `resolveMarket` | Admin | Resolve market with winning outcome |
| `cancelMarket` | Admin | Cancel market (refunds all bets) |
| `claimWinnings` | Public | Claim winnings or refund |

### Data Structures

```solidity
enum MarketState { Active, Resolved, Cancelled }
enum Outcome { None, Yes, No }

struct Market {
    uint256 id;
    string question;
    uint256 resolutionTime;
    MarketState state;
    Outcome winningOutcome;
    uint256 yesPool;
    uint256 noPool;
    address creator;
    // ...
}

struct UserPosition {
    uint256 yesBet;
    uint256 noBet;
    bool claimed;
}
```

### Events

```solidity
event MarketCreated(uint256 indexed marketId, string question, ...);
event BetPlaced(uint256 indexed marketId, address indexed bettor, ...);
event MarketResolved(uint256 indexed marketId, Outcome winningOutcome, ...);
event MarketCancelled(uint256 indexed marketId, ...);
event WinningsClaimed(uint256 indexed marketId, address indexed bettor, ...);
```

---

## Usage Examples

### Creating a Market

```solidity
// Create a market
uint256 marketId = predictionMarket.createMarket(
    "Will Bitcoin reach $100k by 2025?",
    block.timestamp + 7 days,  // Resolution time
    0  // No creation fee
);
```

### Placing a Bet

```solidity
// Approve stablecoin spending
IERC20(stablecoin).approve(address(predictionMarket), 100 * 10**6);

// Place a YES bet
predictionMarket.placeBet(
    marketId,
    Outcome.Yes,
    100 * 10**6  // 100 USDC (6 decimals)
);
```

### Resolving a Market

```solidity
// Resolve market (admin only)
predictionMarket.resolveMarket(
    marketId,
    Outcome.Yes  // YES wins
);
```

### Claiming Winnings

```solidity
// Claim winnings
predictionMarket.claimWinnings(marketId);
```

---

## Deployment

### Constructor Parameters

```solidity
constructor(
    address _stablecoin,        // ERC20 token address
    uint8 _stablecoinDecimals,  // Token decimals (6 for USDC)
    address _admin,             // Admin address
    address _feeRecipient,      // Fee recipient address
    uint256 _maxFeePercentage   // Max fee in basis points (500 = 5%)
)
```

### Environment Variables

```bash
# Required
PRIVATE_KEY=0x...

# RPC URLs
ETHEREUM_SEPOLIA_RPC=https://sepolia.infura.io/v3/...
BASE_SEPOLIA_RPC=https://sepolia.base.org

# Optional (defaults to deployer)
ADMIN_ADDRESS=0x...
FEE_RECIPIENT=0x...
MAX_FEE_PERCENTAGE=500

# For verification
ETHERSCAN_API_KEY=...
```

### Supported Networks

| Chain | Testnet | Testnet Chain ID | Mainnet Chain ID |
|-------|---------|------------------|------------------|
| Ethereum | Sepolia | 11155111 | 1 |
| Base | Sepolia | 84532 | 8453 |
| Polygon | Amoy | 80002 | 137 |
| Arbitrum | Sepolia | 421614 | 42161 |
| Optimism | Sepolia | 11155420 | 10 |
| BNB Smart Chain (BSC) | Testnet | 97 | 56 |

---

## Testing

### Test Structure

```
test/
├── BaseTest.sol              # Common test utilities
├── unit/
│   ├── MarketCreation.t.sol  # Market creation tests
│   ├── Betting.t.sol         # Betting tests
│   ├── Resolution.t.sol      # Resolution tests
│   ├── Cancellation.t.sol    # Cancellation tests
│   ├── Claiming.t.sol        # Claiming tests
│   ├── AccessControl.t.sol   # Access control tests
│   └── ViewFunctions.t.sol   # View function tests
├── integration/
│   └── MarketLifecycle.t.sol # Full lifecycle tests
└── fuzz/
    └── PayoutFuzz.t.sol      # Fuzz tests
```

### Coverage

| Metric | Coverage |
|--------|----------|
| Lines | 98.35% |
| Statements | 94.18% |
| Branches | 87.50% |
| Functions | 100% |

---

## Security

### Security Features

- Reentrancy protection on all state-changing functions
- Access control (admin-only functions)
- Input validation on all external functions
- Emergency pause mechanism
- Checked arithmetic (Solidity 0.8+)

### Known Limitations

- Manual resolution only (no oracle integration)
- Admin has significant control
- Non-upgradeable (by design for v1)
- Decimal handling is deployer responsibility

### Best Practices

1. **Use multisig for admin** - Never use single private key in production
2. **Verify token decimals** - Ensure stablecoin decimals match configuration
3. **Test on testnet first** - Always test thoroughly before mainnet
4. **Monitor deployments** - Set up event monitoring and alerts

---

## Gas Costs

Estimated gas costs (may vary):

| Function | Gas |
|----------|-----|
| createMarket | ~150,000 |
| placeBet | ~80,000 |
| resolveMarket | ~50,000 |
| cancelMarket | ~45,000 |
| claimWinnings | ~70,000 |

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

---

## License

MIT License - see [LICENSE](LICENSE) file.

---

## Disclaimer

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.**

**IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

This project is intended for educational and learning purposes only. The smart contracts have NOT been audited by any professional security firm. Before using any of this code in a production environment:

1. Conduct a thorough security audit
2. Test extensively on testnets
3. Understand the risks involved
4. Consult with blockchain security experts

---

## Links

- [Solana Version](https://github.com/SivaramPg/solana-simple-prediction-market-contract)
- [Documentation](./doc/)
- [Issues](https://github.com/yourusername/evm-simple-prediction-market-contract/issues)

---

<div align="center">

**Star this repo if you find it useful!**

</div>
