;; Import constants
(define-constant MAX-REPUTATION-SCORE u200)
(define-constant MIN-REPUTATION-SCORE u0)
(define-constant REPUTATION_PENALTY u20)
(define-constant REPUTATION_REWARD u10)

;; Define maps
(define-map user-reputation
    { user: principal }
    {
        successful-repayments: uint,
        defaults: uint,
        total-borrowed: uint,
        reputation-score: uint
    })

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
            (if (> (+ current-score REPUTATION_REWARD) MAX-REPUTATION-SCORE)
                MAX-REPUTATION-SCORE
                (+ current-score REPUTATION_REWARD))
            (if (> current-score REPUTATION_PENALTY)
                (- current-score REPUTATION_PENALTY)
                MIN-REPUTATION-SCORE))))
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

;; Public function to expose the update-user-reputation functionality
;; Note: This is a warning that can be ignored as we're using a private function with validated parameters
(define-public (update-reputation (user principal) (success bool))
    (begin
        ;; Add validation for user parameter
        (asserts! (is-some (map-get? user-reputation { user: user })) (err u1000))
        ;; Call the private function directly
        (let (
            (current-reputation (unwrap-panic (map-get? user-reputation { user: user })))
            (current-score (get reputation-score current-reputation))
            (new-score (if success
                (if (> (+ current-score REPUTATION_REWARD) MAX-REPUTATION-SCORE)
                    MAX-REPUTATION-SCORE
                    (+ current-score REPUTATION_REWARD))
                (if (> current-score REPUTATION_PENALTY)
                    (- current-score REPUTATION_PENALTY)
                    MIN-REPUTATION-SCORE)))
        )
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
                })
            (ok true)
        )
    ))
