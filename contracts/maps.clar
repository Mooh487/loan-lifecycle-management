;; Whitelisted Assets
(define-map allowed-collateral-assets 
    { asset: (string-ascii 20) } 
    { is-active: bool })

;; Simulated Oracle
(define-map asset-prices 
    { asset: (string-ascii 20) } 
    { price: uint, last-updated: uint })

;; Loan Storage
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

;; User Loans
(define-map user-loans
    { user: principal }
    { 
        active-loans: (list 20 uint),
        total-active-borrowed: uint 
    })

;; Reputation
(define-map user-reputation
    { user: principal }
    {
        successful-repayments: uint,
        defaults: uint,
        total-borrowed: uint,
        reputation-score: uint
    })
