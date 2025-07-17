;; Doctor Credential Validation Contract
;; Manages healthcare provider licenses, certifications, and access controls

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-DOCTOR-EXISTS (err u301))
(define-constant ERR-DOCTOR-NOT-FOUND (err u302))
(define-constant ERR-INVALID-INPUT (err u303))
(define-constant ERR-CREDENTIAL-EXPIRED (err u304))
(define-constant ERR-INVALID-LICENSE (err u305))

;; Data Variables
(define-data-var next-doctor-id uint u1)
(define-data-var license-renewal-period uint u52560) ;; ~1 year in blocks

;; Data Maps
(define-map doctors
  { doctor-id: uint }
  {
    wallet-address: principal,
    license-number: (string-ascii 50),
    first-name: (string-ascii 50),
    last-name: (string-ascii 50),
    specialization: (string-ascii 100),
    medical-school: (string-ascii 100),
    graduation-year: uint,
    license-state: (string-ascii 20),
    is-verified: bool,
    is-active: bool,
    registration-date: uint,
    last-verification: uint
  }
)

(define-map doctor-wallet-to-id
  { wallet: principal }
  { doctor-id: uint }
)

(define-map license-to-doctor
  { license-number: (string-ascii 50) }
  { doctor-id: uint }
)

(define-map certifications
  { doctor-id: uint, cert-index: uint }
  {
    certification-name: (string-ascii 100),
    issuing-body: (string-ascii 100),
    issue-date: uint,
    expiry-date: uint,
    is-active: bool
  }
)

(define-map doctor-cert-count
  { doctor-id: uint }
  { count: uint }
)

(define-map practice-permissions
  { doctor-id: uint, facility-id: uint }
  {
    granted: bool,
    granted-date: uint,
    expires-at: uint,
    permission-level: uint
  }
)

(define-map verification-history
  { doctor-id: uint, verification-index: uint }
  {
    verified-by: principal,
    verification-date: uint,
    verification-type: (string-ascii 30),
    notes: (string-ascii 200)
  }
)

(define-map doctor-verification-count
  { doctor-id: uint }
  { count: uint }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-doctor-owner (doctor-id uint))
  (match (map-get? doctors { doctor-id: doctor-id })
    doctor-data (is-eq tx-sender (get wallet-address doctor-data))
    false
  )
)

(define-private (is-license-valid (license-number (string-ascii 50)))
  (and
    (> (len license-number) u5)
    (< (len license-number) u51)
  )
)

(define-private (add-verification-record (doctor-id uint) (verification-type (string-ascii 30)) (notes (string-ascii 200)))
  (let
    (
      (current-count (default-to u0 (get count (map-get? doctor-cert-count { doctor-id: doctor-id }))))
      (new-count (+ current-count u1))
    )
    (map-set verification-history
      { doctor-id: doctor-id, verification-index: current-count }
      {
        verified-by: tx-sender,
        verification-date: block-height,
        verification-type: verification-type,
        notes: notes
      }
    )
    (map-set doctor-verification-count
      { doctor-id: doctor-id }
      { count: new-count }
    )
  )
)

;; Public Functions

;; Register a new doctor
(define-public (register-doctor
  (license-number (string-ascii 50))
  (first-name (string-ascii 50))
  (last-name (string-ascii 50))
  (specialization (string-ascii 100))
  (medical-school (string-ascii 100))
  (graduation-year uint)
  (license-state (string-ascii 20))
)
  (let
    (
      (doctor-id (var-get next-doctor-id))
    )
    (asserts! (is-license-valid license-number) ERR-INVALID-LICENSE)
    (asserts! (> (len first-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len last-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len specialization) u0) ERR-INVALID-INPUT)
    (asserts! (> graduation-year u1900) ERR-INVALID-INPUT)
    (asserts! (< graduation-year u2030) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? doctor-wallet-to-id { wallet: tx-sender })) ERR-DOCTOR-EXISTS)
    (asserts! (is-none (map-get? license-to-doctor { license-number: license-number })) ERR-DOCTOR-EXISTS)

    (map-set doctors
      { doctor-id: doctor-id }
      {
        wallet-address: tx-sender,
        license-number: license-number,
        first-name: first-name,
        last-name: last-name,
        specialization: specialization,
        medical-school: medical-school,
        graduation-year: graduation-year,
        license-state: license-state,
        is-verified: false,
        is-active: true,
        registration-date: block-height,
        last-verification: u0
      }
    )

    (map-set doctor-wallet-to-id
      { wallet: tx-sender }
      { doctor-id: doctor-id }
    )

    (map-set license-to-doctor
      { license-number: license-number }
      { doctor-id: doctor-id }
    )

    (add-verification-record doctor-id "REGISTRATION" "Doctor registered in system")
    (var-set next-doctor-id (+ doctor-id u1))
    (ok doctor-id)
  )
)

;; Verify doctor credentials (admin only)
(define-public (verify-doctor (doctor-id uint) (notes (string-ascii 200)))
  (let
    (
      (doctor-data (unwrap! (map-get? doctors { doctor-id: doctor-id }) ERR-DOCTOR-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set doctors
      { doctor-id: doctor-id }
      (merge doctor-data {
        is-verified: true,
        last-verification: block-height
      })
    )

    (add-verification-record doctor-id "CREDENTIAL_VERIFICATION" notes)
    (ok true)
  )
)

;; Add certification to doctor
(define-public (add-certification
  (doctor-id uint)
  (certification-name (string-ascii 100))
  (issuing-body (string-ascii 100))
  (issue-date uint)
  (expiry-date uint)
)
  (let
    (
      (current-count (default-to u0 (get count (map-get? doctor-cert-count { doctor-id: doctor-id }))))
      (new-count (+ current-count u1))
    )
    (asserts! (is-doctor-owner doctor-id) ERR-NOT-AUTHORIZED)
    (asserts! (> (len certification-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len issuing-body) u0) ERR-INVALID-INPUT)
    (asserts! (< issue-date expiry-date) ERR-INVALID-INPUT)

    (map-set certifications
      { doctor-id: doctor-id, cert-index: current-count }
      {
        certification-name: certification-name,
        issuing-body: issuing-body,
        issue-date: issue-date,
        expiry-date: expiry-date,
        is-active: true
      }
    )

    (map-set doctor-cert-count
      { doctor-id: doctor-id }
      { count: new-count }
    )

    (add-verification-record doctor-id "CERTIFICATION_ADDED" certification-name)
    (ok true)
  )
)

;; Grant practice permission at facility
(define-public (grant-practice-permission (doctor-id uint) (facility-id uint) (duration uint) (permission-level uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (<= permission-level u3) ERR-INVALID-INPUT)

    (map-set practice-permissions
      { doctor-id: doctor-id, facility-id: facility-id }
      {
        granted: true,
        granted-date: block-height,
        expires-at: (+ block-height duration),
        permission-level: permission-level
      }
    )

    (add-verification-record doctor-id "PRACTICE_PERMISSION" "Practice permission granted")
    (ok true)
  )
)

;; Suspend doctor (admin only)
(define-public (suspend-doctor (doctor-id uint) (reason (string-ascii 200)))
  (let
    (
      (doctor-data (unwrap! (map-get? doctors { doctor-id: doctor-id }) ERR-DOCTOR-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set doctors
      { doctor-id: doctor-id }
      (merge doctor-data { is-active: false })
    )

    (add-verification-record doctor-id "SUSPENSION" reason)
    (ok true)
  )
)

;; Reactivate doctor (admin only)
(define-public (reactivate-doctor (doctor-id uint) (notes (string-ascii 200)))
  (let
    (
      (doctor-data (unwrap! (map-get? doctors { doctor-id: doctor-id }) ERR-DOCTOR-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set doctors
      { doctor-id: doctor-id }
      (merge doctor-data { is-active: true })
    )

    (add-verification-record doctor-id "REACTIVATION" notes)
    (ok true)
  )
)

;; Read-only Functions

;; Get doctor information
(define-read-only (get-doctor-info (doctor-id uint))
  (map-get? doctors { doctor-id: doctor-id })
)

;; Get doctor by wallet address
(define-read-only (get-doctor-by-wallet (wallet principal))
  (match (map-get? doctor-wallet-to-id { wallet: wallet })
    id-data (map-get? doctors { doctor-id: (get doctor-id id-data) })
    none
  )
)

;; Get doctor by license number
(define-read-only (get-doctor-by-license (license-number (string-ascii 50)))
  (match (map-get? license-to-doctor { license-number: license-number })
    id-data (map-get? doctors { doctor-id: (get doctor-id id-data) })
    none
  )
)

;; Check if doctor is verified and active
(define-read-only (is-doctor-authorized (doctor-id uint))
  (match (map-get? doctors { doctor-id: doctor-id })
    doctor-data (and
      (get is-verified doctor-data)
      (get is-active doctor-data)
    )
    false
  )
)

;; Get doctor certifications
(define-read-only (get-doctor-certifications (doctor-id uint))
  (let
    (
      (cert-count (default-to u0 (get count (map-get? doctor-cert-count { doctor-id: doctor-id }))))
    )
    (ok {
      doctor-id: doctor-id,
      total-certifications: cert-count
    })
  )
)

;; Check practice permission
(define-read-only (has-practice-permission (doctor-id uint) (facility-id uint))
  (match (map-get? practice-permissions { doctor-id: doctor-id, facility-id: facility-id })
    permission (and
      (get granted permission)
      (< block-height (get expires-at permission))
    )
    false
  )
)

;; Get verification history count
(define-read-only (get-verification-count (doctor-id uint))
  (default-to u0 (get count (map-get? doctor-verification-count { doctor-id: doctor-id })))
)

;; Get total doctor count
(define-read-only (get-total-doctors)
  (- (var-get next-doctor-id) u1)
)

;; Check if license needs renewal
(define-read-only (needs-license-renewal (doctor-id uint))
  (match (map-get? doctors { doctor-id: doctor-id })
    doctor-data (>
      (- block-height (get last-verification doctor-data))
      (var-get license-renewal-period)
    )
    false
  )
)
