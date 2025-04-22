;; Import constants and define error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))

;; Define state variables
(define-data-var contract-owner principal tx-sender)

;; Define maps
(define-map allowed-collateral-assets
    { asset: (string-ascii 20) }
    { is-active: bool })

;; Utility functions
(define-private (is-authorized)
    (is-eq tx-sender (var-get contract-owner)))

(define-public (add-collateral-asset (asset (string-ascii 20)))
    (begin
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        (asserts! (> (len asset) u0) ERR-INVALID-AMOUNT)
        (map-set allowed-collateral-assets
            { asset: asset }
            { is-active: true })
        (ok true)))

(define-public (remove-collateral-asset (asset (string-ascii 20)))
    (begin
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        (asserts! (> (len asset) u0) ERR-INVALID-AMOUNT)
        (map-set allowed-collateral-assets
            { asset: asset }
            { is-active: false })
        (ok true)))

;; Define additional error codes
(define-constant ERR-INVALID-COLLATERAL-ASSET (err u1013))

;; Define additional maps
(define-map asset-prices
    { asset: (string-ascii 20) }
    { price: uint, last-updated: uint })

;; Define utility functions
(define-private (is-valid-collateral-asset (asset (string-ascii 20)))
    (match (map-get? allowed-collateral-assets { asset: asset })
        allowed-asset (get is-active allowed-asset)
        false))

(define-public (update-asset-price (asset (string-ascii 20)) (price uint))
    (begin
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        (asserts! (> (len asset) u0) ERR-INVALID-AMOUNT)
        (asserts! (> price u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-collateral-asset asset) ERR-INVALID-COLLATERAL-ASSET)
        (map-set asset-prices
            { asset: asset }
            { price: price, last-updated: burn-block-height })
        (ok true)))
