;; =====================================================
;; RewardLocker - Time-locked STX Rewards with Top-Up
;; ====================================================

(define-constant ERR-ZERO-AMOUNT (err u100))
(define-constant ERR-NOT-CONTRIBUTOR (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u102))
(define-constant ERR-LOCKED (err u103))
(define-constant ERR-INSUFFICIENT-REWARD (err u104))
(define-constant ERR-INVALID-ACTION (err u105))

;; -----------------------------------------------------
;; State
;; -----------------------------------------------------
(define-map contributors
  principal
  { contribution: uint, reward: uint, deposit-time: uint, lock-period: uint, claimed: bool }
)

(define-data-var total-rewards uint u0)

;; Default lock period in blocks (e.g., 30 days)
(define-constant DEFAULT_LOCK_PERIOD u2592000)

;; Helper function to get maximum of two numbers
(define-private (max-uint (a uint) (b uint))
  (if (> a b) a b))

;; -----------------------------------------------------
;; Events
;; -----------------------------------------------------
;; Events are now handled through print statements in Clarity
;; Replace event emissions with print statements in the contract logic

;; =====================================================
;; Single dispatcher function
;; =====================================================
(define-public (rewardLockerAction
    (action (string-ascii 20))
    (amount uint)
    (recipient principal)
    (custom-lock uint))
    (let ((contract-principal (as-contract tx-sender)))
        (if (is-eq action "contribute")
            (begin
                (asserts! (> amount u0) ERR-ZERO-AMOUNT)
                ;; Transfer STX from user to contract
                (try! (stx-transfer? amount tx-sender contract-principal)))

                ;; Calculate reward tier
                (let 
                    ((base-reward
                        (if (>= amount u1000) 
                            (/ (* amount u20) u100) ;; >=1000 STX -> 20%
                            (if (>= amount u500)
                                (/ (* amount u15) u100) ;; 500-999 -> 15%
                                (/ (* amount u10) u100)))) ;; <500 - 10%
                    (bonus (if (< burn-block-height u1000) 
                            (/ (* (if (>= amount u1000) 
                                    (/ (* amount u20) u100)
                                    (if (>= amount u500)
                                        (/ (* amount u15) u100)
                                        (/ (* amount u10) u100))) u5) u100)
                            u0))
                    (total-reward (+ base-reward bonus))
                    (lock-period (if (> custom-lock u0) custom-lock DEFAULT_LOCK_PERIOD))
                    (existing (default-to { contribution: u0, reward: u0, deposit-time: u0, lock-period: u0, claimed: false }
                                        (map-get? contributors tx-sender))))
                    
                    ;; If already claimed, cannot top-up, treat as new contributor
                    (if (get claimed existing)
                        (map-set contributors tx-sender 
                            { contribution: amount
                            , reward: (+ (get reward existing) total-reward)
                            , deposit-time: burn-block-height
                            , lock-period: (max-uint (get lock-period existing) lock-period)
                            , claimed: false })
                        (map-set contributors tx-sender 
                            { contribution: (+ (get contribution existing) amount)
                            , reward: (+ (get reward existing) total-reward)
                            , deposit-time: (get deposit-time existing)
                            , lock-period: (max-uint (get lock-period existing) lock-period)
                            , claimed: false }))
                    
                    ;; Update total reward pool
                    (var-set total-rewards (+ (var-get total-rewards) total-reward))
                    ;; Emit events
                    (if (get claimed existing)
                        (print {type: "rewardlocker-contributed", who: tx-sender, amount: amount, reward: total-reward, lock-period: lock-period})
                        (print {type: "rewardlocker-topped-up", who: tx-sender, amount: amount, additional-reward: total-reward, new-lock-period: (get lock-period (map-get? contributors tx-sender))}))
                    (ok true)))
            
            ;; Not contribute action, check other actions
            (if (is-eq action "claim")
                (let ((c (map-get? contributors tx-sender)))
                    (match c
                        contrib
                        (begin
                            (asserts! (not (get claimed contrib)) ERR-ALREADY-CLAIMED)
                            (asserts! (>= (- burn-block-height (get deposit-time contrib)) (get lock-period contrib)) ERR-LOCKED)
                            (asserts! (>= (var-get total-rewards) (get reward contrib)) ERR-INSUFFICIENT-REWARD)
                            (try! (stx-transfer? (get reward contrib) contract-principal tx-sender))
                            (map-set contributors tx-sender (merge contrib { claimed: true }))
                            (var-set total-rewards (- (var-get total-rewards) (get reward contrib)))
                            (print {type: "rewardlocker-claimed", who: tx-sender, amount: (get reward contrib)})
                            (ok true))
                        none 
                        (err ERR-NOT-CONTRIBUTOR)))
                
                ;; Not claim action, check other actions
                (if (is-eq action "get-contributor")
                    (ok (map-get? contributors recipient))
                    (if (is-eq action "get-total-rewards")
                        (ok (var-get total-rewards))
                        (err ERR-INVALID-ACTION))))))
