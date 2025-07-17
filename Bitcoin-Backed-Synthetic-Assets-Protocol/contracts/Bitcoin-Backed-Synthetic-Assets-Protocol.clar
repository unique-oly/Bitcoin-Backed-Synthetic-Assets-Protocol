
;; title: Bitcoin-Backed-Synthetic-Assets-Protocol

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-VAULT-NOT-FOUND (err u1003))
(define-constant ERR-PRICE-EXPIRED (err u1004))
(define-constant ERR-VAULT-UNDERCOLLATERALIZED (err u1005))
(define-constant ERR-LIQUIDATION-FAILED (err u1006))
(define-constant ERR-POOL-INSUFFICIENT-LIQUIDITY (err u1007))
(define-constant ERR-ASSET-NOT-SUPPORTED (err u1008))
(define-constant ERR-COOLDOWN-PERIOD (err u1009))
(define-constant ERR-MAX-SUPPLY-REACHED (err u1010))
(define-constant ERR-ORACLE-DATA-UNAVAILABLE (err u1011))
(define-constant ERR-GOVERNANCE-REJECTION (err u1012))

;; System parameters
(define-constant MIN-COLLATERALIZATION-RATIO u150) ;; 150%
(define-constant LIQUIDATION-THRESHOLD u120) ;; 120%
(define-constant LIQUIDATION-PENALTY u10) ;; 10%
(define-constant PROTOCOL-FEE u5) ;; 0.5%
(define-constant ORACLE-PRICE-EXPIRY u3600) ;; 1 hour
(define-constant COOLDOWN-PERIOD u86400) ;; 24 hours
(define-constant PRECISION-FACTOR u1000000) ;; 6 decimals


;; Supported Asset Types
(define-map supported-assets
  { asset-id: uint }
  {
    name: (string-ascii 24),
    is-active: bool,
    max-supply: uint,
    current-supply: uint,
    collateral-ratio: uint
  }
)

;; Vaults - where users lock their BTC collateral to mint synthetic assets
(define-map vaults
  { owner: principal, asset-id: uint }
  {
    collateral-amount: uint,
    debt-amount: uint,
    last-update: uint,
    liquidation-in-progress: bool
  }
)

;; Price Oracle data
(define-map asset-prices
  { asset-id: uint }
  {
    price: uint,
    last-update: uint,
    source: principal
  }
)

;; Liquidity Pools
(define-map liquidity-pools
  { asset-id: uint }
  {
    stx-balance: uint,
    synthetic-balance: uint,
    total-shares: uint
  }
)

;; LP Token balances
(define-map lp-balances
  { asset-id: uint, owner: principal }
  { shares: uint }
)

;; User Balances for synthetic assets
(define-map synthetic-asset-balances
  { asset-id: uint, owner: principal }
  { balance: uint }
)

;; Protocol Parameters controlled by governance
(define-data-var protocol-paused bool false)
(define-data-var governance-address principal tx-sender)
(define-data-var treasury-address principal tx-sender)
(define-data-var total-protocol-fees uint u0)

(define-public (set-governance-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (ok (var-set governance-address new-address))
  )
)

(define-public (set-treasury-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (ok (var-set treasury-address new-address))
  )
)

(define-public (pause-protocol)
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused true))
  )
)

(define-public (resume-protocol)
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused false))
  )
)

(define-public (add-supported-asset (asset-id uint) (name (string-ascii 24)) (max-supply uint) (collateral-ratio uint))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (asserts! (>= collateral-ratio MIN-COLLATERALIZATION-RATIO) ERR-INVALID-AMOUNT)
    (ok (map-set supported-assets 
      { asset-id: asset-id } 
      { 
        name: name, 
        is-active: true, 
        max-supply: max-supply, 
        current-supply: u0, 
        collateral-ratio: collateral-ratio 
      }
    ))
  )
)

(define-public (update-asset-status (asset-id uint) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED)
    (match (map-get? supported-assets { asset-id: asset-id })
      asset-data (ok (map-set supported-assets 
        { asset-id: asset-id } 
        (merge asset-data { is-active: is-active })
      ))
      ERR-ASSET-NOT-SUPPORTED
    )
  )
)
