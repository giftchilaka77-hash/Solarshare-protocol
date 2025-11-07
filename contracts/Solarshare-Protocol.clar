;; ------------------------------------------------------------
;; SolarShare Protocol - Decentralized Solar Energy Credit System
;; Functionality: decentralized-solar-energy-credit-system
;; Author: [Your Name]
;; License: MIT
;; ------------------------------------------------------------

;; -----------------------------
;; 1. Constants & Error Codes
;; -----------------------------
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))

;; -----------------------------
;; 2. Token Definition
;; -----------------------------
(define-fungible-token solcr-token)

;; -----------------------------
;; 3. Data Variables & Maps
;; -----------------------------
(define-data-var energy-record-counter uint u0)
(define-map producers principal bool)
(define-map verifiers principal bool)
(define-data-var contract-owner principal tx-sender)

(define-map energy-records
  uint
  {
    producer: principal,
    energy-kwh: uint,
    verified: bool
  }
)

;; -----------------------------
;; 4. Administrative Functions
(define-public (register-producer (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set producers account true)
    (ok "Producer successfully registered")
  )
)

(define-public (register-verifier (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set verifiers account true)
    (ok "Verifier successfully registered")
  )
)

;; -----------------------------
;; 5. Record Energy Production
;; -----------------------------
(define-public (record-energy (energy-kwh uint))
  (begin
    (asserts! (is-eq (default-to false (map-get? producers tx-sender)) true) ERR_UNAUTHORIZED)
    (let ((rec-id (+ (var-get energy-record-counter) u1)))
      (map-set energy-records rec-id
        {
          producer: tx-sender,
          energy-kwh: energy-kwh,
          verified: false
        }
      )
      (var-set energy-record-counter rec-id)
      (ok (tuple (record-id rec-id) (status "recorded")))
    )
  )
)

;; -----------------------------
;; 6. Verify and Reward Energy Production
;; -----------------------------
(define-public (verify-production (rec-id uint))
  (let ((record (map-get? energy-records rec-id)))
    (begin
      (asserts! (is-eq (default-to false (map-get? verifiers tx-sender)) true) ERR_UNAUTHORIZED)
      (asserts! (is-some record) ERR_NOT_FOUND)
      (let ((data (unwrap-panic record)))
        (if (get verified data)
          ERR_ALREADY_VERIFIED
          (let ((set-result (map-set energy-records rec-id
              {
                producer: (get producer data),
                energy-kwh: (get energy-kwh data),
                verified: true
              }
            )))
            ;; Mint $SOLCR reward tokens based on energy generated
            (asserts! (is-ok (ft-mint? solcr-token (get energy-kwh data) (get producer data))) (err u103))
            (ok (tuple (verified true) (reward (get energy-kwh data))))
          )
        )
      )
    )
  )
)

;; -----------------------------
;; 7. Transfer or Donate Energy Credits
;; -----------------------------
(define-public (transfer-credits (recipient principal) (amount uint))
  (begin
    (ft-transfer? solcr-token amount tx-sender recipient)
  )
)

;; -----------------------------
;; 8. Read-only Queries
;; -----------------------------
(define-read-only (get-energy-record (rec-id uint))
  (map-get? energy-records rec-id)
)

(define-read-only (get-total-records)
  (var-get energy-record-counter)
)

(define-read-only (is-producer (account principal))
  (default-to false (map-get? producers account))
)

(define-read-only (is-verifier (account principal))
  (default-to false (map-get? verifiers account))
)
