;; staking-rewards.clar
;; Staking Rewards Contract - Clarity 2.0
;; This contract allows users to stake tokens and earn rewards based on their staked amount over time, facilitating yield farming.

;; Token Definitions
(define-fungible-token staked-token)                             ;; The token that users can stake for rewards.
(define-fungible-token reward-token)                             ;; The token that represents the rewards users earn.

;; Error Constants
(define-constant ERR_NOT_AUTHORIZED (err u1001))               ;; Error: Caller is not authorized for this action.
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))         ;; Error: Insufficient balance to complete the unstake.
(define-constant ERR_INVALID_AMOUNT (err u1003))               ;; Error: The specified amount is invalid.
(define-constant ERR_NOT_ACTIVE (err u1004))                   ;; Error: Contract is not active for staking.
(define-constant ERR_NO_STAKE (err u1005))                     ;; Error: No staked amount found for this user.
(define-constant ERR_ALREADY_CLAIMED (err u1006))              ;; Error: Rewards have already been claimed.

;; State Variables
(define-data-var contract-owner principal tx-sender)             ;; The principal address of the contract owner.
(define-data-var rewards-per-block uint u100)                   ;; Amount of rewards distributed per block.
(define-data-var last-update-block uint block-height)           ;; Block height of the last reward update.
(define-data-var total-rewards-accumulated uint u0)             ;; Total rewards accumulated per share.
(define-data-var total-tokens-staked uint u0)                   ;; Total tokens currently staked in the contract.

;; Staker Information Map
(define-map staker-details 
    principal 
    {
        staked-amount: uint,          ;; Amount of tokens staked by the user.
        reward-debt: uint,            ;; Amount of rewards the user has already claimed.
        last-claim-block: uint         ;; Last block height at which the user claimed rewards.
    }
)

(define-map pending-rewards principal uint)                      ;; Map to track rewards pending for each user.

;; Read-Only Functions
(define-read-only (get-staker-details (staker principal))
    (default-to 
        { staked-amount: u0, reward-debt: u0, last-claim-block: u0 }
        (map-get? staker-details staker)
    )
)

(define-read-only (calculate-pending-reward (staker principal))
    (let (
        (staker-info (get-staker-details staker))
        (current-rewards-per-share (calculate-rewards-per-share))
    )
    (+ 
        (default-to u0 (map-get? pending-rewards staker)) 
        (/
            (* (get staked-amount staker-info) 
               (- current-rewards-per-share (get reward-debt staker-info))) 
            u1000000
        )
    ))
)

(define-read-only (calculate-rewards-per-share)
    (let (
        (blocks-passed (- block-height (var-get last-update-block)))  
        (total-staked (var-get total-tokens-staked))                    
    )
    (if (is-eq total-staked u0)
        (var-get total-rewards-accumulated)                           
        (+
            (var-get total-rewards-accumulated)
            (/
                (* (* blocks-passed (var-get rewards-per-block)) u1000000)
                total-staked
            )
        )
    ))
)

;; Public Functions
(define-public (stake-tokens (amount uint))
    (let (
        (staker tx-sender) 
        (current-rewards-per-share (calculate-rewards-per-share))    
        (staker-info (get-staker-details staker))                    
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)                     ;; Ensure that the staked amount is valid.
    (try! (ft-transfer? staked-token amount staker (as-contract tx-sender))) 

    ;; Update rewards before staking
    (update-rewards)
    
    ;; Update staker information
    (map-set staker-details
        staker
        {
            staked-amount: (+ (get staked-amount staker-info) amount), 
            reward-debt: (/
                (* (+ (get staked-amount staker-info) amount) current-rewards-per-share)
                u1000000
            ),
            last-claim-block: block-height
        }
    )
    
    ;; Update total staked tokens
    (var-set total-tokens-staked (+ (var-get total-tokens-staked) amount))
    (ok true))
)

(define-public (unstake-tokens (amount uint))
    (let (
        (staker tx-sender)
        (staker-info (get-staker-details staker))
        (current-staked-amount (get staked-amount staker-info))       
    )
    (asserts! (>= current-staked-amount amount) ERR_INSUFFICIENT_BALANCE)  

    ;; Claim rewards before unstaking
    (try! (claim-rewards))
    
    ;; Transfer tokens back to the staker
    (try! (as-contract (ft-transfer? staked-token amount (as-contract tx-sender) staker)))
    
    ;; Update staker information after unstaking
    (map-set staker-details
        staker
        {
            staked-amount: (- current-staked-amount amount),
            reward-debt: (/
                (* (- current-staked-amount amount) (calculate-rewards-per-share))
                u1000000
            ),
            last-claim-block: block-height
        }
    )
    
    ;; Update total staked amount
    (var-set total-tokens-staked (- (var-get total-tokens-staked) amount))
    (ok true))
)

(define-public (claim-rewards)
    (let (
        (staker tx-sender)
        (pending (calculate-pending-reward staker))                    
        (current-rewards-per-share (calculate-rewards-per-share))       
    )
    (asserts! (> pending u0) ERR_NO_STAKE)                            ;; Ensure there are rewards to claim.
    
    ;; Update rewards for the staker
    (update-rewards)
    
    ;; Transfer rewards to the staker
    (try! (as-contract (ft-mint? reward-token pending staker)))
    
    ;; Update staker information
    (map-set staker-details
        staker
        (merge
            (get-staker-details staker)
            {
                reward-debt: (/
                    (* (get staked-amount (get-staker-details staker)) current-rewards-per-share)
                    u1000000
                ),
                last-claim-block: block-height
            }
        )
    )
    
    (map-set pending-rewards staker u0)                              ;; Reset pending rewards to zero.
    (ok true))
)

;; Private Functions
(define-private (update-rewards)
    (let (
        (current-rewards-per-share (calculate-rewards-per-share))    
    )
    (var-set total-rewards-accumulated current-rewards-per-share)     ;; Update accumulated rewards.
    (var-set last-update-block block-height))                        ;; Update the last block height.
)

;; Admin Functions
(define-public (set-rewards-rate (new-rate uint))
  (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)  ;; Ensure only the owner can set this.
      (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)                        	;; Validate new rewards rate.
      (var-set rewards-per-block new-rate)                                	;; Set the new rewards per block.
      (ok true))
)

(define-public (emergency-withdraw)
  (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)  ;; Only the owner can withdraw.
      (let (
          (stake-balance (ft-get-balance staked-token (as-contract tx-sender)))	;; Get stake token balance.
          (reward-balance (ft-get-balance reward-token (as-contract tx-sender)))   ;; Get reward token balance.
      )
      ;; Transfer all stake and reward tokens back to the owner.
      (try! (as-contract (ft-transfer? staked-token stake-balance (as-contract tx-sender) (var-get contract-owner))))
      (try! (as-contract (ft-transfer? reward-token reward-balance (as-contract tx-sender) (var-get contract-owner))))
      (ok true)))
)
