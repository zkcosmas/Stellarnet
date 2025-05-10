;; Cosmic Resource Trading Network - Complete System
;; Stage 3: Full-featured platform with rarity classification and advanced pricing

;; System error definitions
(define-constant ACCESS-VIOLATION-CODE (err u301))
(define-constant ALREADY-REGISTERED-CODE (err u302))
(define-constant CREDITS-INSUFFICIENT-CODE (err u303))
(define-constant RESOURCE-NOT-FOUND-CODE (err u304))
(define-constant EXTRACTION-PENDING-CODE (err u305))
(define-constant RESOURCE-MASS-LIMIT-CODE (err u306))
(define-constant EXTRACTION-FEE-BOUNDS-CODE (err u307))
(define-constant STABILITY-PERIOD-CODE (err u308))
(define-constant INVALID-RESOURCE-REFERENCE-CODE (err u309))
(define-constant RARITY-BOUNDS-CODE (err u310))
(define-constant DECOMMISSIONED-STATUS-CODE (err u311))
(define-constant DEPOSIT-TOO-SMALL-CODE (err u312))
(define-constant COORDINATES-EMPTY-CODE (err u313))
(define-constant COMPOSITION-EMPTY-CODE (err u314))
(define-constant NETWORK-MAX-VALUE u2000000000)

;; Core data structures
(define-map cosmic-resource-registry
  { resource-id: uint }
  {
    discoverer: principal,
    current-extractor: (optional principal),
    resource-mass: uint,
    discoverer-fee: uint,
    stability-period: uint,
    rarity-classification: uint,
    registration-timestamp: (optional uint),
    spatial-coordinates: (string-ascii 30),
    elemental-composition: (string-ascii 20),
    trading-status: (string-ascii 20)
  }
)

(define-map credit-repository principal uint)

(define-map explorer-reputation-index principal uint)

(define-map explorer-discovery-registry
  principal
  (list 10 uint)
)

;; Core business logic implementations
(define-public (register-cosmic-discovery (resource-mass uint) (discoverer-fee uint) (stability-period uint) 
                             (rarity-classification uint) (spatial-coordinates (string-ascii 30)) 
                             (elemental-composition (string-ascii 20)))
  (let ((resource-id (+ (var-get discovery-sequence) u1)))
    ;; Input validation suite
    (asserts! (> resource-mass u0) RESOURCE-MASS-LIMIT-CODE)
    (asserts! (<= discoverer-fee u50) EXTRACTION-FEE-BOUNDS-CODE)
    (asserts! (and (> stability-period u0) (<= stability-period u10000)) STABILITY-PERIOD-CODE)
    (asserts! (and (>= rarity-classification u1) (<= rarity-classification u5)) RARITY-BOUNDS-CODE)
    ;; Coordinates and composition validation
    (asserts! (> (len spatial-coordinates) u0) COORDINATES-EMPTY-CODE)
    (asserts! (> (len elemental-composition) u0) COMPOSITION-EMPTY-CODE)
    
    ;; Register the new cosmic resource
    (map-set cosmic-resource-registry 
      { resource-id: resource-id }
      {
        discoverer: tx-sender,
        current-extractor: none,
        resource-mass: resource-mass,
        discoverer-fee: discoverer-fee,
        stability-period: stability-period,
        rarity-classification: rarity-classification,
        registration-timestamp: none,
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
        registration-timestamp: (some block-height),
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

(define-public (complete-extraction (resource-id uint))
  (let (
    (resource-details (unwrap! (map-get? cosmic-resource-registry { resource-id: resource-id }) RESOURCE-NOT-FOUND-CODE))
    (extractor-balance (default-to u0 (map-get? credit-repository tx-sender)))
    (initial-cost (get resource-mass resource-details))
    (discovery-bonus (/ (* (get resource-mass resource-details) (get discoverer-fee resource-details)) u100))
    (rarity-premium (/ (* initial-cost (get rarity-classification resource-details)) u100))
    (total-payment (+ initial-cost discovery-bonus rarity-premium))
  )
    ;; Comprehensive validation checks
    (asserts! (<= resource-id (var-get discovery-sequence)) INVALID-RESOURCE-REFERENCE-CODE)
    (asserts! (is-eq (get current-extractor resource-details) (some tx-sender)) ACCESS-VIOLATION-CODE)
    (asserts! (is-eq (get trading-status resource-details) "RIGHTS_CLAIMED") RESOURCE-NOT-FOUND-CODE)
    (asserts! (>= (- block-height (unwrap! (get registration-timestamp resource-details) RESOURCE-NOT-FOUND-CODE)) 
                (get stability-period resource-details)) EXTRACTION-PENDING-CODE)
    (asserts! (>= extractor-balance total-payment) CREDITS-INSUFFICIENT-CODE)
    
    ;; Execute payment to discoverer
    (map-set credit-repository tx-sender (- extractor-balance total-payment))
    (map-set credit-repository (get discoverer resource-details) 
      (+ (default-to u0 (map-get? credit-repository (get discoverer resource-details))) 
         total-payment)
    )
    
    ;; Update discoverer's reputation score
    (let ((reputation-score (default-to u0 (map-get? explorer-reputation-index 
                        (get discoverer resource-details)))))
      (map-set explorer-reputation-index
        (get discoverer resource-details)
        (+ reputation-score u1)
      )
    )
    
    ;; Update resource lifecycle status
    (map-set cosmic-resource-registry { resource-id: resource-id } 
      (merge resource-details { trading-status: "EXTRACTION_COMPLETE" }))
    (ok true)
  )
)

(define-public (decommission-resource (resource-id uint))
  (let (
    (resource-details (unwrap! (map-get? cosmic-resource-registry { resource-id: resource-id }) RESOURCE-NOT-FOUND-CODE))
  )
    ;; Security validations
    (asserts! (<= resource-id (var-get discovery-sequence)) INVALID-RESOURCE-REFERENCE-CODE)
    (asserts! (is-eq (get discoverer resource-details) tx-sender) ACCESS-VIOLATION-CODE)
    (asserts! (is-eq (get trading-status resource-details) "AVAILABLE") RESOURCE-NOT-FOUND-CODE)
    
    ;; Change trading status
    (map-set cosmic-resource-registry { resource-id: resource-id } 
      (merge resource-details { trading-status: "DECOMMISSIONED" }))
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

(define-read-only (get-explorer-reputation (explorer principal))
  (default-to u0 (map-get? explorer-reputation-index explorer))
)

(define-read-only (list-discovered-resources (entity principal))
  (default-to (list) (map-get? explorer-discovery-registry entity))
)

;; Rarity multiplier calculation
(define-read-only (calculate-rarity-multiplier (rarity-classification uint))
  (if (and (>= rarity-classification u1) (<= rarity-classification u5))
      (* rarity-classification u1)
      u0)  ;; Failsafe default for invalid parameters
)

;; Resource value estimation with rarity consideration
(define-read-only (estimate-resource-value (resource-id uint))
  (let (
    (resource-details (default-to 
                        {
                          discoverer: tx-sender,
                          current-extractor: none,
                          resource-mass: u0,
                          discoverer-fee: u0,
                          stability-period: u0,
                          rarity-classification: u0,
                          registration-timestamp: none,
                          spatial-coordinates: "",
                          elemental-composition: "",
                          trading-status: "NOT_FOUND"
                        }
                        (map-get? cosmic-resource-registry { resource-id: resource-id })))
  )
    (if (is-eq (get trading-status resource-details) "NOT_FOUND")
        u0
        (let (
              (base-value (get resource-mass resource-details))
              (discovery-component (/ (* base-value (get discoverer-fee resource-details)) u100))
              (rarity-component (/ (* base-value (get rarity-classification resource-details)) u100))
             )
          (+ base-value discovery-component rarity-component)
        )
    )
  )
)

;; Advanced resource filtering by rarity
(define-read-only (filter-resources-by-rarity (minimum-rarity uint) (maximum-rarity uint))
  (let (
    (counter u0)
    (matches (list))
  )
    (filter-resources-helper counter matches minimum-rarity maximum-rarity)
  )
)

(define-read-only (filter-resources-helper (counter uint) (matches (list 20 uint)) (minimum-rarity uint) (maximum-rarity uint))
  (if (> counter (var-get discovery-sequence))
      matches
      (let (
        (resource-details (default-to 
                            {
                              discoverer: tx-sender,
                              current-extractor: none,
                              resource-mass: u0,
                              discoverer-fee: u0,
                              stability-period: u0,
                              rarity-classification: u0,
                              registration-timestamp: none,
                              spatial-coordinates: "",
                              elemental-composition: "",
                              trading-status: "NOT_FOUND"
                            }
                            (map-get? cosmic-resource-registry { resource-id: counter })))
      )
        (if (and 
             (is-eq (get trading-status resource-details) "AVAILABLE")
             (>= (get rarity-classification resource-details) minimum-rarity)
             (<= (get rarity-classification resource-details) maximum-rarity))
            (let (
              (updated-matches (unwrap! (as-max-len? (append matches counter) u20) matches))
            )
              (filter-resources-helper (+ counter u1) updated-matches minimum-rarity maximum-rarity)
            )
            (filter-resources-helper (+ counter u1) matches minimum-rarity maximum-rarity)
        )
      )
  )
)

;; Network statistics tracking
(define-map resource-category-statistics
  { rarity: uint }
  { 
    total-discovered: uint,
    total-extracted: uint,
    average-price: uint
  }
)

;; Transaction auditing
(define-map extraction-audit-log
  { resource-id: uint }
  {
    initial-claim-block: uint,
    extraction-complete-block: uint,
    total-payment: uint,
    extractor: principal
  }
)

;; Update statistics after registration
(define-public (update-statistics-after-registration (resource-id uint))
  (let (
    (resource-details (unwrap! (map-get? cosmic-resource-registry { resource-id: resource-id }) RESOURCE-NOT-FOUND-CODE))
    (rarity (get rarity-classification resource-details))
    (existing-stats (default-to 
                     { total-discovered: u0, total-extracted: u0, average-price: u0 }
                     (map-get? resource-category-statistics { rarity: rarity })))
  )
    (map-set resource-category-statistics
      { rarity: rarity }
      (merge existing-stats {
        total-discovered: (+ (get total-discovered existing-stats) u1)
      })
    )
    (ok true)
  )
)

;; Update statistics after extraction
(define-public (update-statistics-after-extraction (resource-id uint) (payment-amount uint))
  (let (
    (resource-details (unwrap! (map-get? cosmic-resource-registry { resource-id: resource-id }) RESOURCE-NOT-FOUND-CODE))
    (rarity (get rarity-classification resource-details))
    (existing-stats (default-to 
                     { total-discovered: u0, total-extracted: u0, average-price: u0 }
                     (map-get? resource-category-statistics { rarity: rarity })))
    (extracted-count (get total-extracted existing-stats))
    (current-avg-price (get average-price existing-stats))
    (new-extracted-count (+ extracted-count u1))
  )
    ;; Calculate new average price
    (let (
      (new-avg-price (if (is-eq extracted-count u0)
                        payment-amount
                        (/ (+ (* current-avg-price extracted-count) payment-amount) new-extracted-count)))
    )
      ;; Update statistics
      (map-set resource-category-statistics
        { rarity: rarity }
        (merge existing-stats {
          total-extracted: new-extracted-count,
          average-price: new-avg-price
        })
      )
      
      ;; Record extraction details in audit log
      (map-set extraction-audit-log
        { resource-id: resource-id }
        {
          initial-claim-block: (unwrap-panic (get registration-timestamp resource-details)),
          extraction-complete-block: block-height,
          total-payment: payment-amount,
          extractor: (unwrap-panic (get current-extractor resource-details))
        }
      )
      (ok true)
    )
  )
)

;; Query market statistics by rarity
(define-read-only (get-market-statistics (rarity uint))
  (default-to 
   { total-discovered: u0, total-extracted: u0, average-price: u0 }
   (map-get? resource-category-statistics { rarity: rarity }))
)

;; Get extraction history for a resource
(define-read-only (get-extraction-history (resource-id uint))
  (map-get? extraction-audit-log { resource-id: resource-id })
)

;; Calculate market efficiency ratio
(define-read-only (calculate-market-efficiency (rarity uint))
  (let (
    (stats (default-to 
           { total-discovered: u0, total-extracted: u0, average-price: u0 }
           (map-get? resource-category-statistics { rarity: rarity })))
  )
    (if (is-eq (get total-discovered stats) u0)
        u0
        (/ (* (get total-extracted stats) u100) (get total-discovered stats))
    )
  )
)

;; System initialization
(define-data-var discovery-sequence uint u0)