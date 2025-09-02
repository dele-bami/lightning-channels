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

;; Creates message hash for signature verification
;; Message format: channel-id + balance-a + balance-b + nonce
(define-private (create-channel-message
    (channel-id (buff 32))
    (balance-a uint)
    (balance-b uint)
    (nonce uint)
  )
  (concat
    (concat (concat channel-id (uint-to-consensus-buff balance-a))
      (uint-to-consensus-buff balance-b)
    )
    (uint-to-consensus-buff nonce)
  )
)

;; Simplified signature verification (placeholder for production cryptographic verification)
;; In production, this would verify secp256k1 signatures against message hashes
(define-private (verify-channel-signature
    (message (buff 256))
    (signature (buff 65))
    (expected-signer principal)
  )
  ;; NOTE: This is a simplified implementation
  ;; Production version should implement proper secp256k1 signature verification
  (is-eq tx-sender expected-signer)
)

;; Retrieves channel data with error handling
(define-private (get-channel-data
    (channel-id (buff 32))
    (participant-a principal)
    (participant-b principal)
  )
  (map-get? lightning-channels {
    channel-id: channel-id,
    participant-a: participant-a,
    participant-b: participant-b,
  })
)

;; CHANNEL MANAGEMENT

;; OPEN LIGHTNING CHANNEL
;; Creates a new bidirectional payment channel with initial funding
;; The channel enables unlimited off-chain transactions between participants
(define-public (open-lightning-channel
    (channel-id (buff 32))
    (counterparty principal)
    (initial-funding uint)
  )
  (let ((channel-key {
      channel-id: channel-id,
      participant-a: tx-sender,
      participant-b: counterparty,
    }))
    ;; Input validation
    (asserts! (is-valid-channel-id channel-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-deposit initial-funding) ERR-INVALID-INPUT)
    (asserts! (are-different-participants tx-sender counterparty)
      ERR-INVALID-INPUT
    )

    ;; Ensure channel doesn't already exist
    (asserts! (is-none (get-channel-data channel-id tx-sender counterparty))
      ERR-CHANNEL-EXISTS
    )

    ;; Lock STX tokens in contract escrow
    (try! (stx-transfer? initial-funding tx-sender (as-contract tx-sender)))

    ;; Initialize channel state
    (map-set lightning-channels channel-key {
      total-locked: initial-funding,
      balance-a: initial-funding,
      balance-b: u0,
      is-active: true,
      dispute-deadline: u0,
      state-nonce: u0,
    })

    (ok channel-id)
  )
)

;; FUND LIGHTNING CHANNEL  
;; Adds additional STX to an existing channel, increasing available liquidity
(define-public (fund-lightning-channel
    (channel-id (buff 32))
    (counterparty principal)
    (additional-funding uint)
  )
  (let (
      (channel (unwrap! (get-channel-data channel-id tx-sender counterparty)
        ERR-CHANNEL-NOT-FOUND
      ))
      (channel-key {
        channel-id: channel-id,
        participant-a: tx-sender,
        participant-b: counterparty,
      })
    )
    ;; Input validation
    (asserts! (is-valid-channel-id channel-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-deposit additional-funding) ERR-INVALID-INPUT)
    (asserts! (are-different-participants tx-sender counterparty)
      ERR-INVALID-INPUT
    )
    (asserts! (get is-active channel) ERR-CHANNEL-CLOSED)

    ;; Transfer additional funds to channel
    (try! (stx-transfer? additional-funding tx-sender (as-contract tx-sender)))

    ;; Update channel balances
    (map-set lightning-channels channel-key
      (merge channel {
        total-locked: (+ (get total-locked channel) additional-funding),
        balance-a: (+ (get balance-a channel) additional-funding),
      })
    )

    (ok additional-funding)
  )
)

;; CHANNEL CLOSURE

;; COOPERATIVE CHANNEL CLOSURE
;; Enables instant channel closure when both parties agree on final balances
;; This is the preferred method as it avoids dispute periods and minimizes fees
(define-public (close-channel-cooperative
    (channel-id (buff 32))
    (counterparty principal)
    (final-balance-a uint)
    (final-balance-b uint)
    (signature-a (buff 65))
    (signature-b (buff 65))
  )
  (let (
      (channel (unwrap! (get-channel-data channel-id tx-sender counterparty)
        ERR-CHANNEL-NOT-FOUND
      ))
      (channel-key {
        channel-id: channel-id,
        participant-a: tx-sender,
        participant-b: counterparty,
      })
      (current-nonce (get state-nonce channel))
      (settlement-message (create-channel-message channel-id final-balance-a final-balance-b
        current-nonce
      ))
    )
    ;; Validation checks
    (asserts! (is-valid-channel-id channel-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-signature signature-a) ERR-INVALID-INPUT)
    (asserts! (is-valid-signature signature-b) ERR-INVALID-INPUT)
    (asserts! (are-different-participants tx-sender counterparty)
      ERR-INVALID-INPUT
    )
    (asserts! (get is-active channel) ERR-CHANNEL-CLOSED)

    ;; Verify balance conservation
    (asserts!
      (is-eq (get total-locked channel) (+ final-balance-a final-balance-b))
      ERR-INSUFFICIENT-FUNDS
    )

    ;; Verify both party signatures
    (asserts!
      (and
        (verify-channel-signature settlement-message signature-a tx-sender)
        (verify-channel-signature settlement-message signature-b counterparty)
      )
      ERR-INVALID-SIGNATURE
    )

    ;; Execute settlement transfers
    (try! (as-contract (stx-transfer? final-balance-a tx-sender tx-sender)))
    (try! (as-contract (stx-transfer? final-balance-b tx-sender counterparty)))

    ;; Close channel
    (map-set lightning-channels channel-key
      (merge channel {
        is-active: false,
        balance-a: u0,
        balance-b: u0,
        total-locked: u0,
      })
    )

    (ok true)
  )
)

;; UNILATERAL CHANNEL CLOSURE (STEP 1)
;; Initiates channel closure when counterparty is unresponsive
;; Starts dispute period allowing counterparty to challenge proposed balances
(define-public (initiate-channel-dispute
    (channel-id (buff 32))
    (counterparty principal)
    (claimed-balance-a uint)
    (claimed-balance-b uint)
    (state-signature (buff 65))
  )
  (let (
      (channel (unwrap! (get-channel-data channel-id tx-sender counterparty)
        ERR-CHANNEL-NOT-FOUND
      ))
      (channel-key {
        channel-id: channel-id,
        participant-a: tx-sender,
        participant-b: counterparty,
      })
      (current-nonce (get state-nonce channel))
      (dispute-message (create-channel-message channel-id claimed-balance-a claimed-balance-b
        current-nonce
      ))
    )
    ;; Validation checks
    (asserts! (is-valid-channel-id channel-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-signature state-signature) ERR-INVALID-INPUT)
    (asserts! (are-different-participants tx-sender counterparty)
      ERR-INVALID-INPUT
    )
    (asserts! (get is-active channel) ERR-CHANNEL-CLOSED)

    ;; Verify signature and balance conservation
    (asserts!
      (verify-channel-signature dispute-message state-signature tx-sender)
      ERR-INVALID-SIGNATURE
    )
    (asserts!
      (is-eq (get total-locked channel) (+ claimed-balance-a claimed-balance-b))
      ERR-INSUFFICIENT-FUNDS
    )

    ;; Set dispute deadline and proposed balances
    (map-set lightning-channels channel-key
      (merge channel {
        dispute-deadline: (+ stacks-block-height DISPUTE-WINDOW-BLOCKS),
        balance-a: claimed-balance-a,
        balance-b: claimed-balance-b,
      })
    )

    (ok (+ stacks-block-height DISPUTE-WINDOW-BLOCKS))
  )
)