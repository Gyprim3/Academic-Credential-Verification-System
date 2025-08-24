# Academic Credential Verification System

A decentralized smart contract platform built on Stacks blockchain for issuing, managing, and verifying educational credentials with cryptographic proof of authenticity.

## Features

- **Institution Registration**: Educational institutions can register and establish their identity on-chain
- **Credential Issuance**: Authorized personnel can issue tamper-proof digital credentials
- **Verification System**: Real-time verification of academic credentials by employers and third parties
- **Decentralized Trust**: Eliminates credential fraud through blockchain immutability

## Smart Contract Functions

### Public Functions
- `register-institution`: Register an educational institution
- `authorize-issuer`: Authorize personnel to issue credentials
- `issue-credential`: Issue a new academic credential
- `verify-credential`: Verify credential authenticity

### Read-Only Functions
- `get-institution-details`: Retrieve institution information
- `get-credential-details`: Get credential details
- `get-issuer-info`: View issuer information
- `get-next-credential-id`: Get next available credential ID

## Usage

Deploy the contract and institutions can begin registering to issue verifiable digital credentials for their graduates.

## License

MIT License
\`\`\`

```clarity file="supply-chain/contracts/product-authenticator.clar"
;; Supply Chain Product Authentication
;; Blockchain-based system for tracking product authenticity and origin

;; Data maps
(define-map manufacturers
  { manufacturer-code: (string-utf8 15) }
  { 
    owner: principal,
    company-name: (string-utf8 80),
    industry-sector: (string-utf8 60),
    founding-year: uint,
    certification-level: uint
  }
)

(define-map product-batches
  { manufacturer-code: (string-utf8 15), batch-number: uint }
  {
    product-category: (string-utf8 120),
    production-facility: principal,
    manufacturing-date: uint,
    quality-grade: uint,
    batch-notes: (string-utf8 400),
    authenticity-confirmed: bool
  }
)

(define-map quality-inspectors
  { inspector: principal }
  {
    inspector-name: (string-utf8 120),
    certified-status: bool,
    certification-timestamp: uint
  }
)

(define-map batch-counters
  { manufacturer-code: (string-utf8 15) }
  { total-batches: uint }
)

;; Error codes
(define-constant ERR-ACCESS-DENIED (err u300))
(define-constant ERR-MANUFACTURER-EXISTS (err u301))
(define-constant ERR-MANUFACTURER-NOT-FOUND (err u302))
(define-constant ERR-NOT-MANUFACTURER-OWNER (err u303))
(define-constant ERR-NOT-CERTIFIED-INSPECTOR (err u304))
(define-constant ERR-BATCH-NOT-FOUND (err u305))
(define-constant ERR-INVALID-INPUT-DATA (err u306))

;; Validation functions
(define-private (validate-non-zero (value uint))
  (> value u0)
)

(define-private (validate-manufacturing-year (year uint))
  (and 
    (>= year u1900) 
    (&lt;= year u2150)
  )
)

(define-private (validate-text-input (value (string-utf8 500)))
  (> (len value) u0)
)

;; Manufacturer registration
(define-public (register-manufacturer 
    (manufacturer-code (string-utf8 15))
    (company-name (string-utf8 80))
    (industry-sector (string-utf8 60))
    (founding-year uint)
    (certification-level uint)
  )
  (begin
    ;; Input validation
    (asserts! (validate-text-input manufacturer-code) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-text-input company-name) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-text-input industry-sector) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-manufacturing-year founding-year) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-non-zero certification-level) ERR-INVALID-INPUT-DATA)
    
    ;; Check manufacturer doesn't exist
    (asserts! (is-none (map-get? manufacturers { manufacturer-code: manufacturer-code })) ERR-MANUFACTURER-EXISTS)
    
    ;; Register manufacturer
    (map-set manufacturers
      { manufacturer-code: manufacturer-code }
      {
        owner: tx-sender,
        company-name: company-name,
        industry-sector: industry-sector,
        founding-year: founding-year,
        certification-level: certification-level
      }
    )
    
    ;; Initialize batch counter
    (map-set batch-counters
      { manufacturer-code: manufacturer-code }
      { total-batches: u0 }
    )
    
    (ok true)
  )
)

;; Register quality inspector
(define-public (register-inspector 
    (inspector-name (string-utf8 120)) 
    (certification-timestamp uint)
  )
  (begin
    ;; Input validation
    (asserts! (validate-text-input inspector-name) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-non-zero certification-timestamp) ERR-INVALID-INPUT-DATA)
    
    ;; Register inspector
    (map-set quality-inspectors
      { inspector: tx-sender }
      {
        inspector-name: inspector-name,
        certified-status: false,
        certification-timestamp: certification-timestamp
      }
    )
    (ok true)
  )
)

;; Create product batch
(define-public (create-product-batch
    (manufacturer-code (string-utf8 15))
    (product-category (string-utf8 120))
    (quality-grade uint)
    (batch-notes (string-utf8 400))
    (manufacturing-date uint)
  )
  (let (
    (validated-code manufacturer-code)
    (validated-category product-category)
    (validated-grade quality-grade)
    (validated-notes batch-notes)
    (validated-date manufacturing-date)
  )
    ;; Input validation
    (asserts! (validate-text-input validated-code) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-text-input validated-category) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-non-zero validated-grade) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-non-zero validated-date) ERR-INVALID-INPUT-DATA)
    
    ;; Retrieve required data
    (let (
      (manufacturer (unwrap! (map-get? manufacturers { manufacturer-code: validated-code }) ERR-MANUFACTURER-NOT-FOUND))
      (inspector (unwrap! (map-get? quality-inspectors { inspector: tx-sender }) ERR-NOT-CERTIFIED-INSPECTOR))
      (counter (default-to { total-batches: u0 } (map-get? batch-counters { manufacturer-code: validated-code })))
      (new-batch-number (+ (get total-batches counter) u1))
    )
      ;; Create product batch
      (map-set product-batches
        { manufacturer-code: validated-code, batch-number: new-batch-number }
        {
          product-category: validated-category,
          production-facility: tx-sender,
          manufacturing-date: validated-date,
          quality-grade: validated-grade,
          batch-notes: validated-notes,
          authenticity-confirmed: false
        }
      )
      
      ;; Update batch counter
      (map-set batch-counters
        { manufacturer-code: validated-code }
        { total-batches: new-batch-number }
      )
      
      (ok new-batch-number)
    )
  )
)

;; Authenticate product batch
(define-public (authenticate-batch
    (manufacturer-code (string-utf8 15))
    (batch-number uint)
  )
  (let (
    (validated-code manufacturer-code)
    (validated-batch-number batch-number)
  )
    ;; Input validation
    (asserts! (validate-text-input validated-code) ERR-INVALID-INPUT-DATA)
    (asserts! (validate-non-zero validated-batch-number) ERR-INVALID-INPUT-DATA)
    
    ;; Retrieve required data
    (let (
      (manufacturer (unwrap! (map-get? manufacturers { manufacturer-code: validated-code }) ERR-MANUFACTURER-NOT-FOUND))
      (batch (unwrap! (map-get? product-batches { manufacturer-code: validated-code, batch-number: validated-batch-number }) ERR-BATCH-NOT-FOUND))
    )
      ;; Check manufacturer ownership
      (asserts! (is-eq (get owner manufacturer) tx-sender) ERR-NOT-MANUFACTURER-OWNER)
      
      ;; Authenticate batch
      (map-set product-batches
        { manufacturer-code: validated-code, batch-number: validated-batch-number }
        (merge batch { authenticity-confirmed: true })
      )
      
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-manufacturer-info (manufacturer-code (string-utf8 15)))
  (map-get? manufacturers { manufacturer-code: manufacturer-code })
)

(define-read-only (get-batch-details (manufacturer-code (string-utf8 15)) (batch-number uint))
  (map-get? product-batches { manufacturer-code: manufacturer-code, batch-number: batch-number })
)

(define-read-only (get-inspector-details (inspector principal))
  (map-get? quality-inspectors { inspector: inspector })
)

(define-read-only (get-total-batches (manufacturer-code (string-utf8 15)))
  (get total-batches (default-to { total-batches: u0 } (map-get? batch-counters { manufacturer-code: manufacturer-code })))
)
