(define-private (is-contract-active)
    (not (var-get emergency-stopped)))

(define-private (is-authorized)
    (is-eq tx-sender (var-get contract-owner)))

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
                (< (- block-height (get last-updated price-info)) MAX-PRICE-AGE))
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
