;; LIGHTNING CHANNELS
;; Trustless Payment Channels for Stacks

;;
;;  Contract: Lightning Channels v1.0
;;  Network: Stacks Blockchain

;;  OVERVIEW:
;;  Lightning Channels brings the power of Bitcoin's Lightning Network to the Stacks
;;  ecosystem, enabling instant, low-cost transactions through bi-directional payment
;;  channels. This implementation allows two parties to conduct unlimited off-chain
;;  transactions with cryptographic security and on-chain settlement guarantees.
;;
;;  KEY FEATURES:
;;  - Trustless bi-directional payment channels
;;  - Off-chain transaction capability with on-chain security
;;  - Cooperative and unilateral channel closure mechanisms
;;  - Dispute resolution with time-locked settlements
;;  - Bitcoin-aligned economic incentives
;;  - STX token native integration
;;
;;  ARCHITECTURE:
;;  The contract implements state channels that lock funds in a multi-party escrow,
;;  allowing participants to update balances off-chain through signed messages.
;;  Final settlement occurs on-chain, inheriting Bitcoin's security model through Stacks.

;; CONSTANTS & CONFIG

;; Contract governance
(define-constant CONTRACT-OWNER tx-sender)

;; Dispute resolution parameters (aligned with Bitcoin block times)
(define-constant DISPUTE-WINDOW-BLOCKS u1008) ;; ~7 days assuming 10min blocks

;; Channel constraints  
(define-constant MAX-CHANNEL-ID-LENGTH u32)
(define-constant SIGNATURE-LENGTH u65)
(define-constant MIN-DEPOSIT u1) ;; Minimum 1 microSTX

;;  ERROR CODES

;; Authorization errors
(define-constant ERR-UNAUTHORIZED (err u100))

;; Channel lifecycle errors  
(define-constant ERR-CHANNEL-EXISTS (err u101))
(define-constant ERR-CHANNEL-NOT-FOUND (err u102))
(define-constant ERR-CHANNEL-CLOSED (err u105))

;; Transaction errors
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-SIGNATURE (err u104))
(define-constant ERR-INVALID-INPUT (err u107))

;; Dispute resolution errors
(define-constant ERR-DISPUTE-PERIOD-ACTIVE (err u106))

;;  DATA STRUCTURES

;; Lightning Channel State
;; Stores the complete state of a payment channel between two participants
(define-map lightning-channels
  ;; Channel Identifier
  {
    channel-id: (buff 32), ;; Unique channel identifier
    participant-a: principal, ;; Channel initiator (funding party)
    participant-b: principal, ;; Channel counterparty
  }
  ;; Channel State
  {
    total-locked: uint, ;; Total STX locked in channel
    balance-a: uint, ;; Current balance of participant A
    balance-b: uint, ;; Current balance of participant B
    is-active: bool, ;; Channel operational status
    dispute-deadline: uint, ;; Block height for dispute resolution
    state-nonce: uint, ;; Prevents replay attacks
  }
)

;; VALIDATION FUNCTIONS

;; Validates channel ID format and length
(define-private (is-valid-channel-id (channel-id (buff 32)))
  (and
    (> (len channel-id) u0)
    (<= (len channel-id) MAX-CHANNEL-ID-LENGTH)
  )
)

;; Validates deposit amount meets minimum requirements
(define-private (is-valid-deposit (amount uint))
  (>= amount MIN-DEPOSIT)
)

;; Validates signature format (65 bytes for secp256k1)
(define-private (is-valid-signature (signature (buff 65)))
  (is-eq (len signature) SIGNATURE-LENGTH)
)

;; Validates that participants are different entities
(define-private (are-different-participants
    (participant-a principal)
    (participant-b principal)
  )
  (not (is-eq participant-a participant-b))
)

;; HELPER FUNCTIONS

;; Converts uint to consensus buffer for signature verification
(define-private (uint-to-consensus-buff (value uint))
  (unwrap-panic (to-consensus-buff? value))
)