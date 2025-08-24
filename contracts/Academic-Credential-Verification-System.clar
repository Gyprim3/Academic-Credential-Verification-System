;; Academic Credential Verification System
;; A decentralized platform for issuing and verifying educational credentials

;; Data maps
(define-map academic-institutions
  { institution-id: (string-utf8 20) }
  { 
    registrar: principal,
    name: (string-utf8 100),
    accreditation-body: (string-utf8 100),
    established-year: uint,
    active-status: bool
  }
)

(define-map student-credentials
  { institution-id: (string-utf8 20), credential-id: uint }
  {
    degree-type: (string-utf8 100),
    issuing-authority: principal,
    issue-timestamp: uint,
    graduation-date: uint,
    student-wallet: principal,
    verification-status: bool
  }
)

(define-map authorized-issuers
  { issuer: principal }
  {
    full-name: (string-utf8 100),
    verified-status: bool,
    authorization-date: uint
  }
)

(define-map credential-sequence
  { institution-id: (string-utf8 20) }
  { next-id: uint }
)

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u200))
(define-constant ERR-INSTITUTION-EXISTS (err u201))
(define-constant ERR-INSTITUTION-NOT-FOUND (err u202))
(define-constant ERR-NOT-REGISTRAR (err u203))
(define-constant ERR-NOT-AUTHORIZED-ISSUER (err u204))
(define-constant ERR-CREDENTIAL-NOT-FOUND (err u205))
(define-constant ERR-INVALID-PARAMETERS (err u206))

;; Input validation helpers
(define-private (validate-positive-uint (value uint))
  (> value u0)
)

(define-private (validate-academic-year (year uint))
  (and 
    (>= year u1800) 
    (<= year u2200)
  )
)

(define-private (validate-string-length (value (string-utf8 500)))
  (> (len value) u0)
)

;; Institution registration
(define-public (register-institution 
    (institution-id (string-utf8 20))
    (name (string-utf8 100))
    (accreditation-body (string-utf8 100))
    (established-year uint)
  )
  (begin
    ;; Parameter validation
    (asserts! (validate-string-length institution-id) ERR-INVALID-PARAMETERS)
    (asserts! (validate-string-length name) ERR-INVALID-PARAMETERS)
    (asserts! (validate-string-length accreditation-body) ERR-INVALID-PARAMETERS)
    (asserts! (validate-academic-year established-year) ERR-INVALID-PARAMETERS)
    
    ;; Ensure institution doesn't exist
    (asserts! (is-none (map-get? academic-institutions { institution-id: institution-id })) ERR-INSTITUTION-EXISTS)
    
    ;; Register institution
    (map-set academic-institutions
      { institution-id: institution-id }
      {
        registrar: tx-sender,
        name: name,
        accreditation-body: accreditation-body,
        established-year: established-year,
        active-status: true
      }
    )
    
    ;; Initialize credential sequence
    (map-set credential-sequence
      { institution-id: institution-id }
      { next-id: u1 }
    )
    
    (ok true)
  )
)

;; Authorize credential issuer
(define-public (authorize-issuer 
    (full-name (string-utf8 100)) 
    (authorization-date uint)
  )
  (begin
    ;; Parameter validation
    (asserts! (validate-string-length full-name) ERR-INVALID-PARAMETERS)
    (asserts! (validate-positive-uint authorization-date) ERR-INVALID-PARAMETERS)
    
    ;; Register authorized issuer
    (map-set authorized-issuers
      { issuer: tx-sender }
      {
        full-name: full-name,
        verified-status: false,
        authorization-date: authorization-date
      }
    )
    (ok true)
  )
)

;; Issue academic credential
(define-public (issue-credential
    (institution-id (string-utf8 20))
    (degree-type (string-utf8 100))
    (graduation-date uint)
    (student-wallet principal)
    (issue-timestamp uint)
  )
  (let (
    (validated-institution-id institution-id)
    (validated-degree-type degree-type)
    (validated-graduation-date graduation-date)
    (validated-student-wallet student-wallet)
    (validated-timestamp issue-timestamp)
  )
    ;; Parameter validation
    (asserts! (validate-string-length validated-institution-id) ERR-INVALID-PARAMETERS)
    (asserts! (validate-string-length validated-degree-type) ERR-INVALID-PARAMETERS)
    (asserts! (validate-positive-uint validated-graduation-date) ERR-INVALID-PARAMETERS)
    (asserts! (validate-positive-uint validated-timestamp) ERR-INVALID-PARAMETERS)
    
    ;; Retrieve necessary data
    (let (
      (institution (unwrap! (map-get? academic-institutions { institution-id: validated-institution-id }) ERR-INSTITUTION-NOT-FOUND))
      (issuer (unwrap! (map-get? authorized-issuers { issuer: tx-sender }) ERR-NOT-AUTHORIZED-ISSUER))
      (sequence (default-to { next-id: u1 } (map-get? credential-sequence { institution-id: validated-institution-id })))
      (current-credential-id (get next-id sequence))
    )
      ;; Issue the credential
      (map-set student-credentials
        { institution-id: validated-institution-id, credential-id: current-credential-id }
        {
          degree-type: validated-degree-type,
          issuing-authority: tx-sender,
          issue-timestamp: validated-timestamp,
          graduation-date: validated-graduation-date,
          student-wallet: validated-student-wallet,
          verification-status: false
        }
      )
      
      ;; Update sequence counter
      (map-set credential-sequence
        { institution-id: validated-institution-id }
        { next-id: (+ current-credential-id u1) }
      )
      
      (ok current-credential-id)
    )
  )
)

;; Verify credential (by institution registrar)
(define-public (verify-credential
    (institution-id (string-utf8 20))
    (credential-id uint)
  )
  (let (
    (validated-institution-id institution-id)
    (validated-credential-id credential-id)
  )
    ;; Parameter validation
    (asserts! (validate-string-length validated-institution-id) ERR-INVALID-PARAMETERS)
    (asserts! (validate-positive-uint validated-credential-id) ERR-INVALID-PARAMETERS)
    
    ;; Retrieve necessary data
    (let (
      (institution (unwrap! (map-get? academic-institutions { institution-id: validated-institution-id }) ERR-INSTITUTION-NOT-FOUND))
      (credential (unwrap! (map-get? student-credentials { institution-id: validated-institution-id, credential-id: validated-credential-id }) ERR-CREDENTIAL-NOT-FOUND))
    )
      ;; Verify registrar authority
      (asserts! (is-eq (get registrar institution) tx-sender) ERR-NOT-REGISTRAR)
      
      ;; Update verification status
      (map-set student-credentials
        { institution-id: validated-institution-id, credential-id: validated-credential-id }
        (merge credential { verification-status: true })
      )
      
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-institution-details (institution-id (string-utf8 20)))
  (map-get? academic-institutions { institution-id: institution-id })
)

(define-read-only (get-credential-details (institution-id (string-utf8 20)) (credential-id uint))
  (map-get? student-credentials { institution-id: institution-id, credential-id: credential-id })
)

(define-read-only (get-issuer-info (issuer principal))
  (map-get? authorized-issuers { issuer: issuer })
)

(define-read-only (get-next-credential-id (institution-id (string-utf8 20)))
  (get next-id (default-to { next-id: u1 } (map-get? credential-sequence { institution-id: institution-id })))
)
