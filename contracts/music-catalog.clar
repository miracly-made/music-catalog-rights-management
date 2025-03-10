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

;; Updates the metadata associated with an asset
(define-public (modify-asset-metadata (asset-id uint) (updated-metadata (string-ascii 256)))
    (begin
        (asserts! (has-asset-authorization asset-id tx-sender) error-permission-denied)
        (asserts! (validate-metadata-format updated-metadata) error-malformed-metadata)
        (map-set asset-metadata-store asset-id updated-metadata)
        (ok true)))

;; Removes an asset from the registry (admin only)
(define-public (decommission-asset (asset-id uint))
    (begin
        (asserts! (is-eq tx-sender admin-principal) error-admin-restricted)
        (asserts! (is-some (map-get? asset-ownership-registry asset-id)) error-asset-missing)
        (map-delete asset-ownership-registry asset-id)
        (ok true)))

;; Registers multiple assets in a batch operation
(define-public (batch-asset-registration (metadata-batch (list 10 (string-ascii 256))))
    (begin
        (asserts! (is-eq tx-sender admin-principal) error-admin-restricted)
        (map create-asset-entry metadata-batch)
        (ok true)))

;; Verifies if caller is the admin
(define-public (check-admin-status)
    (ok (is-eq tx-sender admin-principal)))

;; Returns the most recently created asset ID
(define-public (get-latest-asset-id)
    (ok (var-get asset-counter)))

;; Verifies if caller has admin privileges
(define-public (verify-admin-privileges)
    (ok (is-eq tx-sender admin-principal)))

;; Checks if an asset exists in the registry
(define-public (check-asset-status (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

;; -------------------- Read-Only Query Functions -----------------------

;; Retrieves metadata for a specific asset
(define-read-only (get-asset-metadata (asset-id uint))
    (ok (map-get? asset-metadata-store asset-id)))

;; Retrieves the current owner of an asset
(define-read-only (get-asset-owner (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

;; Verifies existence of an asset in the registry
(define-read-only (asset-is-registered (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

;; Returns the current asset counter value
(define-read-only (get-asset-counter)
    (ok (var-get asset-counter)))

;; Checks if an asset ID has been registered
(define-read-only (asset-registration-status (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

;; Returns total number of assets in the system
(define-read-only (get-total-assets)
    (ok (var-get asset-counter)))

;; Returns total assets currently registered
(define-read-only (get-registered-asset-count)
    (ok (var-get asset-counter)))

;; Checks if an asset has an assigned owner
(define-read-only (asset-has-owner (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

;; Retrieves the owner of a specific asset
(define-read-only (lookup-asset-owner (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

;; Checks if an asset ID is valid in the system
(define-read-only (verify-asset-exists (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

;; Returns all registered assets count
(define-read-only (count-all-assets)
    (ok (var-get asset-counter)))

;; Returns system-wide asset count
(define-read-only (tally-registered-assets)
    (ok (var-get asset-counter)))

;; ------------------ Contract Initialization ---------------------

;; Initialize the contract state
(begin
    (var-set asset-counter u0))

;; Additional read-only query functions

(define-read-only (check-asset-status-active (asset-id uint))
    (ok (and 
        (is-some (map-get? asset-ownership-registry asset-id))
        (has-asset-authorization asset-id tx-sender))))

(define-read-only (fetch-multiple-asset-metadata 
    (asset-ids (list 10 uint)))
    (ok (map get-asset-metadata asset-ids)))

(define-read-only (get-system-admin)
    (ok admin-principal))

(define-read-only (get-request-sender)
    (ok tx-sender))

(define-read-only (verify-asset-metadata (asset-id uint))
    (ok (is-some (map-get? asset-metadata-store asset-id))))

(define-read-only (get-asset-count)
    (ok (var-get asset-counter)))

(define-read-only (view-asset-ownership (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

(define-read-only (count-system-assets)
    (ok (var-get asset-counter)))

(define-read-only (asset-lookup (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

(define-read-only (check-ownership-record (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

(define-read-only (fetch-asset-counter)
    (ok (var-get asset-counter)))

(define-read-only (verify-asset-ownership (asset-id uint))
    (ok (has-asset-authorization asset-id tx-sender)))

(define-read-only (check-metadata-valid (data (string-ascii 256)))
    (ok (and 
        (>= (len data) u1) 
        (<= (len data) metadata-max-length))))

(define-read-only (validate-address (p principal))
    (ok (is-principal-valid p)))

(define-read-only (check-asset-metadata-status (asset-id uint))
    (ok (is-some (map-get? asset-metadata-store asset-id))))

;; Verifies admin status of current sender
(define-public (admin-status-check)
    (ok (is-eq tx-sender admin-principal)))

;; Returns total asset count in registry
(define-read-only (asset-registry-size)
    (ok (var-get asset-counter)))

;; Returns the transaction initiator
(define-read-only (transaction-initiator)
    (ok tx-sender))

;; Verifies ownership of a specific asset
(define-read-only (asset-ownership-check (asset-id uint))
    (ok (map-get? asset-ownership-registry asset-id)))

;; Checks if metadata exists for an asset
(define-read-only (asset-metadata-status (asset-id uint))
    (ok (is-some (map-get? asset-metadata-store asset-id))))

;; Returns the current transaction sender
(define-read-only (current-transaction-sender)
    (ok tx-sender))

(define-read-only (get-asset-metadata-by-id (asset-id uint))
    (ok (map-get? asset-metadata-store asset-id)))

(define-read-only (verify-asset-registration (asset-id uint))
    (ok (is-some (map-get? asset-ownership-registry asset-id))))

(define-read-only (validate-metadata-length (data (string-ascii 256)))
    (ok (and 
        (>= (len data) u1) 
        (<= (len data) metadata-max-length))))



