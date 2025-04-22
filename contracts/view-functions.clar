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
