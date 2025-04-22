;; Import maps from maps.clar

;; Import error codes
(define-constant ERR-LOAN-NOT-FOUND (err u1003))

;; Define state variables
(define-data-var emergency-stopped bool false)
(define-data-var contract-owner principal tx-sender)

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

(define-map user-reputation
    { user: principal }
    {
        successful-repayments: uint,
        defaults: uint,
        total-borrowed: uint,
        reputation-score: uint
    })

(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id }))

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation { user: user }))

(define-read-only (get-contract-status)
    (var-get emergency-stopped))

(define-read-only (get-contract-owner)
    (var-get contract-owner))

(define-read-only (calculate-total-due (loan-id uint))
    (match (map-get? loans { loan-id: loan-id })
        loan (ok (+ (get amount loan)
                    (/ (* (get amount loan) (get interest-rate loan)) u100)))
        ERR-LOAN-NOT-FOUND))
