;; Import constants and define error codes
(define-constant ERR-PRICE-FEED-FAILURE (err u1012))
(define-constant MIN-COLLATERAL-RATIO u200)
(define-constant MAX-PRICE-AGE u1440)
(define-constant LIQUIDATION-THRESHOLD u80)

;; Define state variables
(define-data-var emergency-stopped bool false)
(define-data-var contract-owner principal tx-sender)

(define-private (is-contract-active)
    (not (var-get emergency-stopped)))

(define-private (is-authorized)
    (is-eq tx-sender (var-get contract-owner)))

;; Define maps
(define-map allowed-collateral-assets
    { asset: (string-ascii 20) }
    { is-active: bool })

(define-map asset-prices
    { asset: (string-ascii 20) }
    { price: uint, last-updated: uint })

(define-map loans
    { loan-id: uint }
    {
        borrower: principal,
        amount: uint,
        collateral-amount: uint,
        collateral-asset: (string-ascii 20),
        interest-rate: uint,
        start-height: uint,
        duration: uint,
        status: (string-ascii 20),
        lenders: (list 20 principal),
        repaid-amount: uint,
        liquidation-price-threshold: uint
    })

(define-private (is-valid-collateral-asset (asset (string-ascii 20)))
    (match (map-get? allowed-collateral-assets { asset: asset })
        allowed-asset (get is-active allowed-asset)
        false))

(define-private (calculate-collateral-ratio (loan-amount uint) (collateral-amount uint))
    (/ (* collateral-amount u100) loan-amount))

(define-private (is-sufficient-collateral (loan-amount uint) (collateral-amount uint))
    (>= (calculate-collateral-ratio loan-amount collateral-amount) MIN-COLLATERAL-RATIO))

(define-private (calculate-liquidation-threshold (current-price uint))
    (/ (* current-price LIQUIDATION-THRESHOLD) u100))

(define-private (get-current-asset-price (asset (string-ascii 20)))
    (match (map-get? asset-prices { asset: asset })
        price-info
        (if (and
                (> (get price price-info) u0)
                (< (- burn-block-height (get last-updated price-info)) MAX-PRICE-AGE))
            (ok (get price price-info))
            (err ERR-PRICE-FEED-FAILURE))
        (err ERR-PRICE-FEED-FAILURE)))

(define-private (is-collateral-above-liquidation-threshold (loan-id uint))
    (match (map-get? loans { loan-id: loan-id })
        loan
        (match (get-current-asset-price (get collateral-asset loan))
            current-price-ok
            (>= current-price-ok (get liquidation-price-threshold loan))
            err-code
            false)
        false))
