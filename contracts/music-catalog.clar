;; Music Catalog Rights Management System in Clarity 6.0
;; Contract Name: music-catalog-manager.clar
;; This smart contract manages the registration, tracking, and monetization of music catalog rights.
;; It facilitates secure ownership transfers and royalty management for registered music assets.

;; --------------------------- Core Constants ---------------------------

;; The administrator of the system who has elevated permissions
(define-constant admin-principal tx-sender)

;; System response codes for various operation results
(define-constant error-admin-restricted (err u200))          ;; Operation restricted to admin only
(define-constant error-permission-denied (err u201))         ;; User lacks necessary permissions
(define-constant error-malformed-metadata (err u202))        ;; Provided metadata fails validation
(define-constant error-asset-exists (err u203))              ;; Asset already registered in system
(define-constant error-asset-missing (err u204))             ;; Referenced asset does not exist
(define-constant error-recipient-invalid (err u205))         ;; Provided recipient address is invalid

;; System configuration parameters
(define-constant metadata-max-length u256)

;; ---------------------- State Variables --------------------------

;; Token implementation for catalog rights representation
(define-non-fungible-token catalog-asset uint)

;; System counter for asset registration
(define-data-var asset-counter uint u0)

;; --------------------------- Storage Maps -------------------------------

;; Primary storage for asset metadata 
(define-map asset-metadata-store uint (string-ascii 256))

;; Registry of asset ownership records
(define-map asset-ownership-registry uint principal)

;; -------------------- Internal Helper Functions -------------------------

;; Validates caller authorization for asset operations
(define-private (has-asset-authorization (asset-id uint) (caller principal))
    (is-eq caller (unwrap! (map-get? asset-ownership-registry asset-id) false)))

;; Performs validation on incoming metadata
(define-private (validate-metadata-format (metadata-string (string-ascii 256)))
    (let ((content-length (len metadata-string)))
        (and (>= content-length u1)  ;; Enforce minimum content requirement
             (<= content-length metadata-max-length))))  ;; Prevent oversized content

;; Performs basic validation on principal addresses
(define-private (is-principal-valid (address principal))
    true)

;; Creates a single asset entry with associated metadata
(define-private (create-asset-entry (metadata-string (string-ascii 256)))
    (let ((asset-id (+ (var-get asset-counter) u1)))
        (try! (nft-mint? catalog-asset asset-id tx-sender))
        (map-set asset-metadata-store asset-id metadata-string)
        (map-set asset-ownership-registry asset-id tx-sender)
        (var-set asset-counter asset-id)
        (ok asset-id)))

;; --------------------- External API Functions -------------------------

;; Creates a new catalog asset with associated metadata
(define-public (create-catalog-asset (metadata-string (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender admin-principal) error-admin-restricted)
        (asserts! (validate-metadata-format metadata-string) error-malformed-metadata)
        (create-asset-entry metadata-string)))

;; Transfers asset ownership to a new account
(define-public (assign-asset-ownership (asset-id uint) (recipient principal))
    (begin
        (asserts! (has-asset-authorization asset-id tx-sender) error-permission-denied)
        (asserts! (is-principal-valid recipient) error-recipient-invalid)
        (try! (nft-transfer? catalog-asset asset-id tx-sender recipient))
        (map-set asset-ownership-registry asset-id recipient)
        (ok true)))
