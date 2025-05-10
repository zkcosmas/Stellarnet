;; Cosmic Resource Trading Network - Basic Framework
;; Stage 1: Core functionality for resource registration and trading

;; System error definitions
(define-constant ACCESS-VIOLATION-CODE (err u301))
(define-constant ALREADY-REGISTERED-CODE (err u302))
(define-constant CREDITS-INSUFFICIENT-CODE (err u303))
(define-constant RESOURCE-NOT-FOUND-CODE (err u304))
(define-constant INVALID-RESOURCE-REFERENCE-CODE (err u309))
(define-constant DEPOSIT-TOO-SMALL-CODE (err u312))
(define-constant NETWORK-MAX-VALUE u2000000000)

;; Core data structures
(define-map cosmic-resource-registry
  { resource-id: uint }
  {
    discoverer: principal,
    current-extractor: (optional principal),
    resource-mass: uint,
    spatial-coordinates: (string-ascii 30),
    elemental-composition: (string-ascii 20),
    trading-status: (string-ascii 20)
  }
)

(define-map credit-repository principal uint)

(define-map explorer-discovery-registry
  principal
  (list 10 uint)
)

;; Core business logic implementations
(define-public (register-cosmic-discovery (resource-mass uint) (spatial-coordinates (string-ascii 30)) 
                             (elemental-composition (string-ascii 20)))
  (let ((resource-id (+ (var-get discovery-sequence) u1)))
    ;; Input validation
    (asserts! (> resource-mass u0) (err u306))
    
    ;; Register the new cosmic resource
    (map-set cosmic-resource-registry 
      { resource-id: resource-id }
      {
        discoverer: tx-sender,
        current-extractor: none,
        resource-mass: resource-mass,
        spatial-coordinates: spatial-coordinates,
        elemental-composition: elemental-composition,
        trading-status: "AVAILABLE"
      }
    )
    
    ;; Update the discoverer's portfolio record
    (let 
      (
        (existing-portfolio (default-to (list) (map-get? explorer-discovery-registry tx-sender)))
        (refreshed-portfolio (unwrap-panic (as-max-len? (concat (list resource-id) existing-portfolio) u10)))
      )
      ;; Maintain at most 10 most recent discoveries
      (map-set explorer-discovery-registry tx-sender refreshed-portfolio)
    )
    
    (var-set discovery-sequence resource-id)
    (ok resource-id)
  )
)

(define-public (claim-extraction-rights (resource-id uint))
  (let (
    (resource-details (unwrap! (map-get? cosmic-resource-registry { resource-id: resource-id }) RESOURCE-NOT-FOUND-CODE))
    (extractor-credits (default-to u0 (map-get? credit-repository tx-sender)))
  )
    ;; Validate transaction parameters
    (asserts! (<= resource-id (var-get discovery-sequence)) INVALID-RESOURCE-REFERENCE-CODE)
    (asserts! (is-none (get current-extractor resource-details)) ALREADY-REGISTERED-CODE)
    (asserts! (is-eq (get trading-status resource-details) "AVAILABLE") RESOURCE-NOT-FOUND-CODE)
    (asserts! (>= extractor-credits (get resource-mass resource-details)) CREDITS-INSUFFICIENT-CODE)
    
    ;; Update resource ownership records
    (map-set cosmic-resource-registry { resource-id: resource-id }
      (merge resource-details { 
        current-extractor: (some tx-sender),
        trading-status: "RIGHTS_CLAIMED"
      })
    )
    
    ;; Execute financial transactions
    (map-set credit-repository tx-sender (- extractor-credits (get resource-mass resource-details)))
    (map-set credit-repository (get discoverer resource-details) 
      (+ (default-to u0 (map-get? credit-repository (get discoverer resource-details))) 
         (get resource-mass resource-details)))
    
    (ok true)
  )
)

(define-public (deposit-credits (amount uint))
  (let (
    (existing-balance (default-to u0 (map-get? credit-repository tx-sender)))
  )
    ;; Input validation
    (asserts! (> amount u0) DEPOSIT-TOO-SMALL-CODE)
    (asserts! (<= amount NETWORK-MAX-VALUE) DEPOSIT-TOO-SMALL-CODE)
    (asserts! (<= (+ existing-balance amount) NETWORK-MAX-VALUE) DEPOSIT-TOO-SMALL-CODE)
    
    ;; Update account balance
    (map-set credit-repository tx-sender (+ existing-balance amount))
    (ok true)
  )
)

;; System query interfaces
(define-read-only (query-resource-data (resource-id uint))
  (map-get? cosmic-resource-registry { resource-id: resource-id })
)

(define-read-only (check-explorer-balance (entity principal))
  (default-to u0 (map-get? credit-repository entity))
)

(define-read-only (list-discovered-resources (entity principal))
  (default-to (list) (map-get? explorer-discovery-registry entity))
)

;; System initialization
(define-data-var discovery-sequence uint u0)