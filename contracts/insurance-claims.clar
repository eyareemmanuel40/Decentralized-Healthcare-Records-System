;; Insurance Claim Verification Contract
;; Automates healthcare payment processing and claim verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-CLAIM-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u503))
(define-constant ERR-INSUFFICIENT-COVERAGE (err u504))
(define-constant ERR-POLICY-EXPIRED (err u505))
(define-constant ERR-PROVIDER-NOT-AUTHORIZED (err u506))

;; Data Variables
(define-data-var next-claim-id uint u1)
(define-data-var next-policy-id uint u1)
(define-data-var claim-processing-fee uint u100) ;; Fee in microSTX

;; Data Maps
(define-map insurance-policies
  { policy-id: uint }
  {
    patient-id: uint,
    insurance-company: (string-ascii 100),
    policy-number: (string-ascii 50),
    group-number: (string-ascii 50),
    effective-date: uint,
    expiry-date: uint,
    deductible: uint,
    deductible-met: uint,
    out-of-pocket-max: uint,
    out-of-pocket-met: uint,
    copay-primary: uint,
    copay-specialist: uint,
    is-active: bool
  }
)

(define-map insurance-claims
  { claim-id: uint }
  {
    policy-id: uint,
    patient-id: uint,
    provider-id: uint,
    service-date: uint,
    service-code: (string-ascii 20),
    service-description: (string-ascii 200),
    billed-amount: uint,
    allowed-amount: uint,
    patient-responsibility: uint,
    insurance-payment: uint,
    claim-status: (string-ascii 20),
    submission-date: uint,
    processed-date: uint,
    denial-reason: (optional (string-ascii 200))
  }
)

(define-map authorized-providers
  { provider-id: uint }
  {
    name: (string-ascii 100),
    npi-number: (string-ascii 20),
    tax-id: (string-ascii 20),
    address: (string-ascii 200),
    phone: (string-ascii 20),
    specialty: (string-ascii 100),
    is-active: bool,
    contract-rate: uint
  }
)

(define-map coverage-rules
  { service-code: (string-ascii 20) }
  {
    coverage-percentage: uint,
    requires-preauth: bool,
    copay-amount: uint,
    annual-limit: uint,
    description: (string-ascii 200)
  }
)

(define-map claim-processing-log
  { claim-id: uint, log-index: uint }
  {
    action: (string-ascii 30),
    performed-by: principal,
    timestamp: uint,
    notes: (string-ascii 200),
    amount-involved: uint
  }
)

(define-map claim-log-count
  { claim-id: uint }
  { count: uint }
)

(define-map patient-policies
  { patient-id: uint }
  { policy-id: uint }
)

(define-map annual-usage
  { policy-id: uint, service-code: (string-ascii 20) }
  {
    total-used: uint,
    claim-count: uint,
    last-service-date: uint
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-provider (provider-id uint))
  (match (map-get? authorized-providers { provider-id: provider-id })
    provider-data (get is-active provider-data)
    false
  )
)

(define-private (calculate-patient-responsibility (policy-id uint) (service-code (string-ascii 20)) (billed-amount uint))
  (let
    (
      (policy-data (unwrap-panic (map-get? insurance-policies { policy-id: policy-id })))
      (coverage-rule (map-get? coverage-rules { service-code: service-code }))
    )
    (match coverage-rule
      rule (let
        (
          (coverage-pct (get coverage-percentage rule))
          (copay (get copay-amount rule))
          (covered-amount (/ (* billed-amount coverage-pct) u100))
          (patient-portion (- billed-amount covered-amount))
        )
        (+ patient-portion copay)
      )
      billed-amount ;; No coverage rule means patient pays full amount
    )
  )
)

(define-private (log-claim-action (claim-id uint) (action (string-ascii 30)) (notes (string-ascii 200)) (amount uint))
  (let
    (
      (current-count (default-to u0 (get count (map-get? claim-log-count { claim-id: claim-id }))))
      (new-count (+ current-count u1))
    )
    (map-set claim-processing-log
      { claim-id: claim-id, log-index: current-count }
      {
        action: action,
        performed-by: tx-sender,
        timestamp: block-height,
        notes: notes,
        amount-involved: amount
      }
    )
    (map-set claim-log-count
      { claim-id: claim-id }
      { count: new-count }
    )
  )
)

;; Public Functions

;; Register insurance policy
(define-public (register-policy
  (patient-id uint)
  (insurance-company (string-ascii 100))
  (policy-number (string-ascii 50))
  (group-number (string-ascii 50))
  (effective-date uint)
  (expiry-date uint)
  (deductible uint)
  (out-of-pocket-max uint)
  (copay-primary uint)
  (copay-specialist uint)
)
  (let
    (
      (policy-id (var-get next-policy-id))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len insurance-company) u0) ERR-INVALID-INPUT)
    (asserts! (> (len policy-number) u0) ERR-INVALID-INPUT)
    (asserts! (< effective-date expiry-date) ERR-INVALID-INPUT)

    (map-set insurance-policies
      { policy-id: policy-id }
      {
        patient-id: patient-id,
        insurance-company: insurance-company,
        policy-number: policy-number,
        group-number: group-number,
        effective-date: effective-date,
        expiry-date: expiry-date,
        deductible: deductible,
        deductible-met: u0,
        out-of-pocket-max: out-of-pocket-max,
        out-of-pocket-met: u0,
        copay-primary: copay-primary,
        copay-specialist: copay-specialist,
        is-active: true
      }
    )

    (map-set patient-policies
      { patient-id: patient-id }
      { policy-id: policy-id }
    )

    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

;; Register healthcare provider
(define-public (register-provider
  (provider-id uint)
  (name (string-ascii 100))
  (npi-number (string-ascii 20))
  (tax-id (string-ascii 20))
  (address (string-ascii 200))
  (phone (string-ascii 20))
  (specialty (string-ascii 100))
  (contract-rate uint)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len npi-number) u0) ERR-INVALID-INPUT)

    (map-set authorized-providers
      { provider-id: provider-id }
      {
        name: name,
        npi-number: npi-number,
        tax-id: tax-id,
        address: address,
        phone: phone,
        specialty: specialty,
        is-active: true,
        contract-rate: contract-rate
      }
    )
    (ok true)
  )
)

;; Add coverage rule
(define-public (add-coverage-rule
  (service-code (string-ascii 20))
  (coverage-percentage uint)
  (requires-preauth bool)
  (copay-amount uint)
  (annual-limit uint)
  (description (string-ascii 200))
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= coverage-percentage u100) ERR-INVALID-INPUT)
    (asserts! (> (len service-code) u0) ERR-INVALID-INPUT)

    (map-set coverage-rules
      { service-code: service-code }
      {
        coverage-percentage: coverage-percentage,
        requires-preauth: requires-preauth,
        copay-amount: copay-amount,
        annual-limit: annual-limit,
        description: description
      }
    )
    (ok true)
  )
)

;; Submit insurance claim
(define-public (submit-claim
  (patient-id uint)
  (provider-id uint)
  (service-date uint)
  (service-code (string-ascii 20))
  (service-description (string-ascii 200))
  (billed-amount uint)
)
  (let
    (
      (claim-id (var-get next-claim-id))
      (policy-ref (unwrap! (map-get? patient-policies { patient-id: patient-id }) ERR-CLAIM-NOT-FOUND))
      (policy-id (get policy-id policy-ref))
      (policy-data (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR-POLICY-EXPIRED))
      (patient-responsibility (calculate-patient-responsibility policy-id service-code billed-amount))
      (insurance-payment (- billed-amount patient-responsibility))
    )
    (asserts! (is-authorized-provider provider-id) ERR-PROVIDER-NOT-AUTHORIZED)
    (asserts! (get is-active policy-data) ERR-POLICY-EXPIRED)
    (asserts! (< service-date (get expiry-date policy-data)) ERR-POLICY-EXPIRED)
    (asserts! (> billed-amount u0) ERR-INVALID-INPUT)
    (asserts! (> (len service-code) u0) ERR-INVALID-INPUT)

    (map-set insurance-claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        patient-id: patient-id,
        provider-id: provider-id,
        service-date: service-date,
        service-code: service-code,
        service-description: service-description,
        billed-amount: billed-amount,
        allowed-amount: billed-amount,
        patient-responsibility: patient-responsibility,
        insurance-payment: insurance-payment,
        claim-status: "SUBMITTED",
        submission-date: block-height,
        processed-date: u0,
        denial-reason: none
      }
    )

    (log-claim-action claim-id "CLAIM_SUBMITTED" service-description billed-amount)
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Process insurance claim (admin only)
(define-public (process-claim (claim-id uint) (approved bool) (allowed-amount uint) (denial-reason (optional (string-ascii 200))))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
      (new-status (if approved "APPROVED" "DENIED"))
      (final-insurance-payment (if approved (- allowed-amount (get patient-responsibility claim-data)) u0))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get claim-status claim-data) "SUBMITTED") ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (if approved (> allowed-amount u0) true) ERR-INVALID-INPUT)

    (map-set insurance-claims
      { claim-id: claim-id }
      (merge claim-data {
        allowed-amount: allowed-amount,
        insurance-payment: final-insurance-payment,
        claim-status: new-status,
        processed-date: block-height,
        denial-reason: denial-reason
      })
    )

    (if approved
      (begin
        (log-claim-action claim-id "CLAIM_APPROVED" "Claim processed and approved" final-insurance-payment)
        (update-annual-usage (get policy-id claim-data) (get service-code claim-data) allowed-amount)
      )
      (log-claim-action claim-id "CLAIM_DENIED" (unwrap-panic denial-reason) u0)
    )

    (ok true)
  )
)

;; Update annual usage tracking
(define-private (update-annual-usage (policy-id uint) (service-code (string-ascii 20)) (amount uint))
  (let
    (
      (current-usage (map-get? annual-usage { policy-id: policy-id, service-code: service-code }))
    )
    (match current-usage
      usage (map-set annual-usage
        { policy-id: policy-id, service-code: service-code }
        {
          total-used: (+ (get total-used usage) amount),
          claim-count: (+ (get claim-count usage) u1),
          last-service-date: block-height
        }
      )
      (map-set annual-usage
        { policy-id: policy-id, service-code: service-code }
        {
          total-used: amount,
          claim-count: u1,
          last-service-date: block-height
        }
      )
    )
  )
)

;; Appeal claim decision
(define-public (appeal-claim (claim-id uint) (appeal-reason (string-ascii 200)))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    )
    (asserts! (is-eq (get claim-status claim-data) "DENIED") ERR-INVALID-INPUT)
    (asserts! (> (len appeal-reason) u0) ERR-INVALID-INPUT)

    (map-set insurance-claims
      { claim-id: claim-id }
      (merge claim-data { claim-status: "UNDER_APPEAL" })
    )

    (log-claim-action claim-id "APPEAL_SUBMITTED" appeal-reason u0)
    (ok true)
  )
)

;; Update policy deductible and out-of-pocket amounts
(define-public (update-policy-usage (policy-id uint) (deductible-amount uint) (out-of-pocket-amount uint))
  (let
    (
      (policy-data (unwrap! (map-get? insurance-policies { policy-id: policy-id }) ERR-CLAIM-NOT-FOUND))
      (new-deductible-met (+ (get deductible-met policy-data) deductible-amount))
      (new-out-of-pocket-met (+ (get out-of-pocket-met policy-data) out-of-pocket-amount))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-deductible-met (get deductible policy-data)) ERR-INVALID-INPUT)
    (asserts! (<= new-out-of-pocket-met (get out-of-pocket-max policy-data)) ERR-INVALID-INPUT)

    (map-set insurance-policies
      { policy-id: policy-id }
      (merge policy-data {
        deductible-met: new-deductible-met,
        out-of-pocket-met: new-out-of-pocket-met
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get insurance policy
(define-read-only (get-policy (policy-id uint))
  (map-get? insurance-policies { policy-id: policy-id })
)

;; Get patient's policy
(define-read-only (get-patient-policy (patient-id uint))
  (match (map-get? patient-policies { patient-id: patient-id })
    policy-ref (map-get? insurance-policies { policy-id: (get policy-id policy-ref) })
    none
  )
)

;; Get claim details
(define-read-only (get-claim (claim-id uint))
  (map-get? insurance-claims { claim-id: claim-id })
)

;; Get provider information
(define-read-only (get-provider-info (provider-id uint))
  (map-get? authorized-providers { provider-id: provider-id })
)

;; Get coverage rule
(define-read-only (get-coverage-rule (service-code (string-ascii 20)))
  (map-get? coverage-rules { service-code: service-code })
)

;; Check policy eligibility
(define-read-only (is-policy-active (policy-id uint))
  (match (map-get? insurance-policies { policy-id: policy-id })
    policy-data (and
      (get is-active policy-data)
      (< block-height (get expiry-date policy-data))
    )
    false
  )
)

;; Get annual usage for service
(define-read-only (get-annual-usage (policy-id uint) (service-code (string-ascii 20)))
  (map-get? annual-usage { policy-id: policy-id, service-code: service-code })
)

;; Calculate estimated coverage
(define-read-only (estimate-coverage (policy-id uint) (service-code (string-ascii 20)) (billed-amount uint))
  (let
    (
      (patient-responsibility (calculate-patient-responsibility policy-id service-code billed-amount))
      (insurance-payment (- billed-amount patient-responsibility))
    )
    (ok {
      billed-amount: billed-amount,
      patient-responsibility: patient-responsibility,
      insurance-payment: insurance-payment,
      coverage-percentage: (/ (* insurance-payment u100) billed-amount)
    })
  )
)

;; Get claim processing log count
(define-read-only (get-claim-log-count (claim-id uint))
  (default-to u0 (get count (map-get? claim-log-count { claim-id: claim-id })))
)

;; Get total claims count
(define-read-only (get-total-claims)
  (- (var-get next-claim-id) u1)
)

;; Get total policies count
(define-read-only (get-total-policies)
  (- (var-get next-policy-id) u1)
)
