# Lightning Channels for Stacks

[![Stacks](https://img.shields.io/badge/Built%20on-Stacks-5546FF?style=flat&logo=stacks)](https://stacks.co)
[![Clarity](https://img.shields.io/badge/Smart%20Contract-Clarity-brightgreen)](https://clarity-lang.org)
[![License](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen)](tests/)

A trustless payment channel implementation for the Stacks blockchain, bringing Lightning Network-style off-chain transactions to the Stacks ecosystem with Bitcoin-aligned security guarantees.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Running Tests](#running-tests)
- [Contract Reference](#contract-reference)
  - [Core Functions](#core-functions)
  - [Read-Only Functions](#read-only-functions)
  - [Data Structures](#data-structures)
- [Usage Examples](#usage-examples)
- [Security Considerations](#security-considerations)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Overview

Lightning Channels extends the Lightning Network concept to the Stacks blockchain, enabling instant, low-cost transactions through bi-directional payment channels. This implementation allows two parties to conduct unlimited off-chain transactions with cryptographic security while maintaining on-chain settlement guarantees.

### Key Benefits

- **Instant Transactions**: Off-chain payments settle immediately without waiting for block confirmations
- **Low Fees**: Avoid per-transaction fees by settling only the final state on-chain
- **Trustless Operation**: No trusted intermediaries required; security backed by smart contracts
- **Bitcoin Security**: Inherits Bitcoin's security model through the Stacks blockchain
- **Dispute Resolution**: Built-in mechanisms for handling uncooperative participants

## Features

- ✅ **Bi-directional Payment Channels**: Enable payments in both directions between participants
- ✅ **Cooperative Channel Closure**: Instant settlement when both parties agree
- ✅ **Unilateral Channel Closure**: Force closure with dispute resolution mechanism
- ✅ **Time-locked Disputes**: 7-day dispute window aligned with Bitcoin block times
- ✅ **Signature Verification**: Cryptographic proof of state transitions
- ✅ **STX Token Integration**: Native support for Stacks (STX) tokens
- ✅ **Emergency Recovery**: Owner-controlled fund recovery for critical situations

## Architecture

The Lightning Channels contract implements state channels that:

1. **Lock Funds**: STX tokens are escrowed in the smart contract
2. **Off-chain Updates**: Participants exchange signed balance updates off-chain
3. **On-chain Settlement**: Final balances are settled on the Stacks blockchain
4. **Dispute Resolution**: Uncooperative behavior is handled through time-locked disputes

```text
┌─────────────┐    Off-chain     ┌─────────────┐
│             │◄────Balance────► │             │
│ Participant │     Updates      │ Participant │
│      A      │                  │      B      │
│             │                  │             │
└─────────────┘                  └─────────────┘
       │                                │
       │         On-chain Settlement    │
       └────────────────┬───────────────┘
                        │
                ┌───────▼────────┐
                │                │
                │ Lightning      │
                │ Channels       │
                │ Smart Contract │
                │                │
                └────────────────┘
```

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v2.0+
- [Node.js](https://nodejs.org/) v18+
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/dele-bami/lightning-channels.git
   cd lightning-channels
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Verify installation**

   ```bash
   clarinet check
   ```

### Running Tests

Execute the test suite to verify contract functionality:

```bash
# Run all tests
npm test

# Run tests with coverage report
npm run test:report

# Watch mode for development
npm run test:watch
```

## Contract Reference

### Core Functions

#### Channel Management

#### `open-lightning-channel`

Creates a new bi-directional payment channel with initial funding.

```clarity
(open-lightning-channel 
  (channel-id (buff 32)) 
  (counterparty principal) 
  (initial-funding uint))
```

- **Parameters**:
  - `channel-id`: Unique identifier for the channel (max 32 bytes)
  - `counterparty`: Address of the channel participant
  - `initial-funding`: Initial STX amount to lock (minimum 1 microSTX)
- **Returns**: `(response (buff 32) uint)` - Channel ID on success

#### `fund-lightning-channel`

Adds additional STX to an existing channel.

```clarity
(fund-lightning-channel 
  (channel-id (buff 32)) 
  (counterparty principal) 
  (additional-funding uint))
```

#### Channel Closure

#### `close-channel-cooperative`

Instant channel closure when both parties agree on final balances.

```clarity
(close-channel-cooperative 
  (channel-id (buff 32)) 
  (counterparty principal) 
  (final-balance-a uint) 
  (final-balance-b uint) 
  (signature-a (buff 65)) 
  (signature-b (buff 65)))
```

#### `initiate-channel-dispute`

Starts unilateral closure process with dispute period.

```clarity
(initiate-channel-dispute 
  (channel-id (buff 32)) 
  (counterparty principal) 
  (claimed-balance-a uint) 
  (claimed-balance-b uint) 
  (state-signature (buff 65)))
```

#### `finalize-channel-dispute`

Completes channel closure after dispute period expires.

```clarity
(finalize-channel-dispute 
  (channel-id (buff 32)) 
  (counterparty principal))
```

### Read-Only Functions

#### `get-lightning-channel-status`

Returns complete channel information.

```clarity
(get-lightning-channel-status 
  (channel-id (buff 32)) 
  (participant-a principal) 
  (participant-b principal))
```

#### `get-channel-balances`

Returns current balance distribution.

```clarity
(get-channel-balances 
  (channel-id (buff 32)) 
  (participant-a principal) 
  (participant-b principal))
```

#### `is-channel-active`

Quick check if channel is operational.

```clarity
(is-channel-active 
  (channel-id (buff 32)) 
  (participant-a principal) 
  (participant-b principal))
```

### Data Structures

#### Channel State

```clarity
{
  total-locked: uint,        ;; Total STX locked in channel
  balance-a: uint,           ;; Current balance of participant A  
  balance-b: uint,           ;; Current balance of participant B
  is-active: bool,           ;; Channel operational status
  dispute-deadline: uint,    ;; Block height for dispute resolution
  state-nonce: uint,         ;; Prevents replay attacks
}
```

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR-UNAUTHORIZED` | Caller lacks required permissions |
| 101 | `ERR-CHANNEL-EXISTS` | Channel already exists |
| 102 | `ERR-CHANNEL-NOT-FOUND` | Channel does not exist |
| 103 | `ERR-INSUFFICIENT-FUNDS` | Insufficient balance for operation |
| 104 | `ERR-INVALID-SIGNATURE` | Signature verification failed |
| 105 | `ERR-CHANNEL-CLOSED` | Channel is not active |
| 106 | `ERR-DISPUTE-PERIOD-ACTIVE` | Dispute period still active |
| 107 | `ERR-INVALID-INPUT` | Invalid input parameters |

## Usage Examples

### Opening a Channel

```clarity
;; Open a channel with 1000 STX initial funding
(contract-call? 
  .lightning-channels 
  open-lightning-channel 
  0x1234567890abcdef1234567890abcdef12345678 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u1000000000) ;; 1000 STX in microSTX
```

### Cooperative Channel Closure

```clarity
;; Close channel with agreed final balances
(contract-call? 
  .lightning-channels 
  close-channel-cooperative 
  0x1234567890abcdef1234567890abcdef12345678
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u600000000  ;; 600 STX to participant A
  u400000000  ;; 400 STX to participant B
  signature-a
  signature-b)
```

### Checking Channel Status

```clarity
;; Get complete channel information
(contract-call? 
  .lightning-channels 
  get-lightning-channel-status 
  0x1234567890abcdef1234567890abcdef12345678
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## Security Considerations

### Current Implementation Notes

⚠️ **Important**: This is a demonstration implementation with simplified components:

- **Signature Verification**: Uses simplified verification for demonstration. Production deployment requires full secp256k1 signature verification.
- **Message Hashing**: Implements basic message construction. Production should use standardized hashing schemes.
- **Nonce Management**: Current implementation uses basic nonce tracking. Enhanced replay protection recommended for production.

### Security Best Practices

1. **Verify Signatures**: Always verify cryptographic signatures before state transitions
2. **Monitor Disputes**: Watch for dispute initiations and respond within the 7-day window
3. **Backup State**: Keep secure backups of latest channel states and signatures
4. **Validate Balances**: Ensure balance conservation in all operations
5. **Use Cooperative Closure**: Prefer cooperative closure to minimize fees and disputes

### Audit Recommendations

Before mainnet deployment:

- [ ] Comprehensive security audit by qualified blockchain security firms
- [ ] Formal verification of critical contract properties
- [ ] Stress testing with high transaction volumes
- [ ] Integration testing with wallet interfaces
- [ ] Gas optimization analysis

## Development

### Project Structure

```text
lightning-channels/
├── contracts/
│   └── lightning-channels.clar     # Main contract implementation
├── tests/
│   └── lightning-channels.test.ts  # Comprehensive test suite
├── settings/
│   ├── Devnet.toml                # Development network config
│   ├── Testnet.toml               # Testnet configuration
│   └── Mainnet.toml               # Mainnet configuration
├── Clarinet.toml                  # Project configuration
├── package.json                   # Node.js dependencies
└── vitest.config.js              # Test configuration
```

### Development Workflow

1. **Make Changes**: Edit contracts or tests
2. **Check Syntax**: `clarinet check`
3. **Run Tests**: `npm test`
4. **Integration Test**: Deploy to devnet/testnet
5. **Code Review**: Submit pull request

### Adding Features

When adding new features:

1. Write tests first (TDD approach)
2. Implement the feature in Clarity
3. Ensure all existing tests pass
4. Add documentation for new functions
5. Update this README if needed

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Test** your changes thoroughly
4. **Commit** your changes (`git commit -m 'Add amazing feature'`)
5. **Push** to the branch (`git push origin feature/amazing-feature`)
6. **Open** a Pull Request

### Code Standards

- Follow Clarity best practices and naming conventions
- Add comprehensive tests for new functionality
- Include JSDoc comments for all public functions
- Ensure code passes all linting checks

### Issues

Found a bug or have a feature request? Please [open an issue](https://github.com/dele-bami/lightning-channels/issues) with:

- Clear description of the problem or feature
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Relevant code snippets or logs

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Stacks Foundation](https://stacks.org/) for the blockchain infrastructure
- [Clarity](https://clarity-lang.org/) for the smart contract language
- [Lightning Network](https://lightning.network/) for the inspiration and concepts
- The Stacks developer community for tools and support
