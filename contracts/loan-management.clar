(define-public (create-loan-request 
    (amount uint) 
    (collateral uint) 
    (collateral-asset (string-ascii 20)) 
    (duration uint) 
    (interest-rate uint))
    (let
        ((loan-id (var-get next-loan-id))
         (tx-sender-account tx-sender)
         (current-asset-price (unwrap! 
                (get-current-asset-price collateral-asset) 
                ERR-PRICE-FEED-FAILURE)))
        (asserts! (is-contract-active) ERR-EMERGENCY-STOP)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> collateral u0) ERR-INSUFFICIENT-COLLATERAL)
        (asserts! (is-sufficient-collateral amount collateral) ERR-INSUFFICIENT-COLLATERAL)
        (asserts! (is-valid-collateral-asset collateral-asset) ERR-INVALID-COLLATERAL-ASSET)
        (asserts! (and (>= duration MIN-DURATION) (<= duration MAX-DURATION)) ERR-INVALID-DURATION)
        (asserts! (<= interest-rate MAX-INTEREST-RATE) ERR-INVALID-INTEREST-RATE)

        (map-set loans
            { loan-id: loan-id }
            {
                borrower: tx-sender-account,
                amount: amount,
                collateral-amount: collateral,
                collateral-asset: collateral-asset,
                interest-rate: interest-rate,
                start-height: block-height,
                duration: duration,
                status: "PENDING",
                lenders: (list),
                repaid-amount: u0,
                liquidation-price-threshold: (calculate-liquidation-threshold current-asset-price)
            })

        (let ((existing-user-loans (default-to 
            { active-loans: (list), total-active-borrowed: u0 }
            (map-get? user-loans { user: tx-sender-account }))))
            (map-set user-loans
                { user: tx-sender-account }
                { 
                    active-loans: (unwrap-panic (as-max-len? 
                        (append (get active-loans existing-user-loans) loan-id) u20)),
                    total-active-borrowed: (+ 
                        (get total-active-borrowed existing-user-loans) 
                        amount)
                }))

        (var-set next-loan-id (+ loan-id u1))
        (ok loan-id)))

(define-public (activate-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND)))
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status loan) "PENDING") ERR-LOAN-ALREADY-ACTIVE)
        (map-set loans { loan-id: loan-id }
            (merge loan { status: "ACTIVE", start-height: block-height }))
        (ok true)))

(define-public (liquidate-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND)))
        (asserts! (is-contract-active) ERR-EMERGENCY-STOP)
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-ACTIVE)
        (asserts! 
            (or 
                (> block-height (+ (get start-height loan) (get duration loan)))
                (not (is-collateral-above-liquidation-threshold loan-id))) 
            ERR-LOAN-NOT-DEFAULTED)
        (map-set loans { loan-id: loan-id } (merge loan { status: "LIQUIDATED" }))
        (update-user-reputation (get borrower loan) false)
        (ok true)))
