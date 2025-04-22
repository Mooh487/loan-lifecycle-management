;; Import constants and error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1002))
(define-constant ERR-LOAN-NOT-FOUND (err u1003))
(define-constant ERR-LOAN-ALREADY-ACTIVE (err u1004))
(define-constant ERR-LOAN-NOT-ACTIVE (err u1005))
(define-constant ERR-LOAN-NOT-DEFAULTED (err u1006))
(define-constant ERR-EMERGENCY-STOP (err u1011))
(define-constant ERR-PRICE-FEED-FAILURE (err u1012))
(define-constant ERR-INVALID-COLLATERAL-ASSET (err u1013))
(define-constant ERR-INVALID-DURATION (err u1009))
(define-constant ERR-INVALID-INTEREST-RATE (err u1010))

;; Define constants
(define-constant MIN-COLLATERAL-RATIO u200)
(define-constant MAX-INTEREST-RATE u5000)
(define-constant MIN-DURATION u1440)
(define-constant MAX-DURATION u525600)

;; Define state variables
(define-data-var emergency-stopped bool false)
(define-data-var contract-owner principal tx-sender)
(define-data-var next-loan-id uint u1)

;; Define maps
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

(define-map user-loans
    { user: principal }
    {
        active-loans: (list 20 uint),
        total-active-borrowed: uint
    })

(define-map allowed-collateral-assets
    { asset: (string-ascii 20) }
    { is-active: bool })

(define-map asset-prices
    { asset: (string-ascii 20) }
    { price: uint, last-updated: uint })

;; Utility functions
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
    (/ (* current-price u80) u100))

(define-private (get-current-asset-price (asset (string-ascii 20)))
    (match (map-get? asset-prices { asset: asset })
        price-info
        (if (and
                (> (get price price-info) u0)
                (< (- burn-block-height (get last-updated price-info)) u1440))
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
                start-height: burn-block-height,
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
            (merge loan { status: "ACTIVE", start-height: burn-block-height }))
        (ok true)))

;; Define user reputation map
(define-map user-reputation
    { user: principal }
    {
        successful-repayments: uint,
        defaults: uint,
        total-borrowed: uint,
        reputation-score: uint
    })

;; Define reputation constants
(define-constant MAX-REPUTATION-SCORE u200)
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant REPUTATION_PENALTY u20)
(define-constant REPUTATION_REWARD u10)

;; Define update-user-reputation function
(define-private (update-user-reputation (user principal) (success bool))
    (let (
        (current-reputation (default-to
            {
                successful-repayments: u0,
                defaults: u0,
                total-borrowed: u0,
                reputation-score: u100
            }
            (map-get? user-reputation { user: user })
        ))
        (current-score (get reputation-score current-reputation))
        (new-score (if success
            (if (> (+ current-score REPUTATION_REWARD) MAX-REPUTATION-SCORE)
                MAX-REPUTATION-SCORE
                (+ current-score REPUTATION_REWARD))
            (if (> current-score REPUTATION_PENALTY)
                (- current-score REPUTATION_PENALTY)
                MIN-REPUTATION-SCORE)
        ))
    )
        (map-set user-reputation
            { user: user }
            {
                successful-repayments: (if success
                    (+ (get successful-repayments current-reputation) u1)
                    (get successful-repayments current-reputation)
                ),
                defaults: (if success
                    (get defaults current-reputation)
                    (+ (get defaults current-reputation) u1)
                ),
                total-borrowed: (get total-borrowed current-reputation),
                reputation-score: new-score
            }
        )
    )
)

(define-public (liquidate-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND)))
        (asserts! (is-contract-active) ERR-EMERGENCY-STOP)
        (asserts! (is-eq (get status loan) "ACTIVE") ERR-LOAN-NOT-ACTIVE)
        (asserts!
            (or
                (> burn-block-height (+ (get start-height loan) (get duration loan)))
                (not (is-collateral-above-liquidation-threshold loan-id)))
            ERR-LOAN-NOT-DEFAULTED)
        (map-set loans { loan-id: loan-id } (merge loan { status: "LIQUIDATED" }))
        (update-user-reputation (get borrower loan) false)
        (ok true)
    )
)
