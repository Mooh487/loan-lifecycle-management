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

(define-public (update-asset-price (asset (string-ascii 20)) (price uint))
    (begin
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        (asserts! (> (len asset) u0) ERR-INVALID-AMOUNT)
        (asserts! (> price u0) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-collateral-asset asset) ERR-INVALID-COLLATERAL-ASSET)
        (map-set asset-prices 
            { asset: asset }
            { price: price, last-updated: block-height })
        (ok true)))
