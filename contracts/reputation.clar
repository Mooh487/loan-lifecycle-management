(define-private (update-user-reputation (user principal) (success bool))
    (let (
        (current-reputation (default-to
            { 
                successful-repayments: u0, 
                defaults: u0, 
                total-borrowed: u0,
                reputation-score: u100 
            }
            (map-get? user-reputation { user: user })))
        (current-score (get reputation-score current-reputation))
        (new-score (if success
            (min MAX-REPUTATION-SCORE (+ current-score REPUTATION_REWARD))
            (max MIN-REPUTATION-SCORE (- current-score REPUTATION_PENALTY)))))
    (map-set user-reputation
        { user: user }
        {
            successful-repayments: (if success 
                (+ (get successful-repayments current-reputation) u1)
                (get successful-repayments current-reputation)),
            defaults: (if success 
                (get defaults current-reputation)
                (+ (get defaults current-reputation) u1)),
            total-borrowed: (get total-borrowed current-reputation),
            reputation-score: new-score
        })))
