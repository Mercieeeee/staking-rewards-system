;; staking-rewards.clar
;; Enhanced Staking Rewards Contract - Clarity 6.0
;; This contract allows users to stake tokens and earn rewards based on their staked amount over time,
;; with additional functionality for tracking staking and rewards history.

;; ** Contract Overview **
;; This contract enables users to stake a specific fungible token (staked-token) and earn rewards in 
;; the form of another fungible token (reward-token). It also supports functionalities for tracking 
;; staking actions, reward claims, and storing historical data related to staking and rewards for each user.

;; The contract provides functions for:
;; - Staking and unstaking tokens
;; - Claiming rewards based on staked amounts
;; - Viewing staking and rewards history
;; - Managing staking rewards rate (admin functionality)

;; ** Token Definitions **
;; Define the staked token and reward token used in the contract
(define-fungible-token staked-token)
(define-fungible-token reward-token)

;; ** Error Constants **
;; Define error codes for different failure scenarios in the contract
(define-constant ERR_NOT_AUTHORIZED (err u1001))  ;; Error if the caller is not authorized (e.g., admin actions)
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))  ;; Error if the user doesn't have enough tokens to unstake
(define-constant ERR_INVALID_AMOUNT (err u1003))  ;; Error if the provided amount is invalid
(define-constant ERR_NOT_ACTIVE (err u1004))  ;; Error if the staking action is not active
(define-constant ERR_NO_STAKE (err u1005))  ;; Error if the user has no stake to claim rewards
(define-constant ERR_ALREADY_CLAIMED (err u1006))  ;; Error if rewards have already been claimed
(define-constant ERR_INVALID_INDEX (err u1007))  ;; Error if the specified index for reward history is invalid

;; ** State Variables **
;; These are the state variables that track the contract's state, including owner, staking data, and rewards
(define-data-var contract-owner principal tx-sender)  ;; Store the contract owner's address (only the owner can update reward rate, etc.)
(define-data-var rewards-per-block uint u100)  ;; Store the rewards given per block (reward rate)
(define-data-var last-update-block uint block-height)  ;; Store the block height at which rewards were last updated
(define-data-var total-rewards-accumulated uint u0)  ;; Track the total rewards accumulated in the contract
(define-data-var total-tokens-staked uint u0)  ;; Track the total amount of tokens staked in the contract

;; ** New History Tracking Variables **
;; These variables track the history of stake actions and reward claims for users
(define-data-var total-stake-actions uint u0)  ;; Track the total number of stake actions performed
(define-data-var total-reward-claims uint u0)  ;; Track the total number of reward claims made

;; ** Enhanced Staker Information Map **
;; This map stores detailed information about each staker's activity and rewards
(define-map staker-details 
    principal  ;; key: the user's principal address
    {
        staked-amount: uint,  ;; Amount of tokens currently staked
        reward-debt: uint,  ;; Reward debt carried over from previous staking
        last-claim-block: uint,  ;; Block height when the user last claimed rewards
        total-staked-lifetime: uint,  ;; Total amount staked by the user over time
        total-unstaked-lifetime: uint,  ;; Total amount unstaked by the user over time
        total-rewards-claimed: uint,  ;; Total rewards claimed by the user
        stake-count: uint,  ;; Total number of staking actions performed by the user
        claim-count: uint  ;; Total number of reward claims made by the user
    }
)

;; ** New History Tracking Maps **
;; These maps track specific staking and reward claim actions
(define-map staking-history
    { user: principal, action-id: uint }  ;; key: user address and action ID
    {
        action-type: (string-ascii 10),  ;; Action type: "stake" or "unstake"
        amount: uint,  ;; Amount of tokens involved in the action
        block-height: uint,  ;; Block height when the action occurred
        timestamp: uint  ;; Timestamp of the action
    }
)

(define-map rewards-history
    { user: principal, claim-id: uint }  ;; key: user address and claim ID
    {
        amount: uint,  ;; Amount of rewards claimed
        block-height: uint,  ;; Block height when the claim occurred
        timestamp: uint  ;; Timestamp of the claim
    }
)

(define-map pending-rewards principal uint)  ;; Map to track pending rewards for each user

;; ** Enhanced Read-Only Functions Section **
;; The following read-only functions provide users with the ability to query staking and rewards information

;; Get total staked amount for a specific user
(define-read-only (get-staked-amount (user principal))
    (get staked-amount (get-staker-details user))
)

;; Get total staked amount across all users
(define-read-only (get-total-staked-amount)
    (var-get total-tokens-staked)
)

;; Get claimable rewards for a specific user
(define-read-only (get-claimable-rewards (user principal))
    (let (
        (staker-info (get-staker-details user))
        (current-rewards-per-share (calculate-rewards-per-share))
        (pending-reward (calculate-pending-reward user))
    )
    {
        pending-amount: pending-reward,
        last-claim-block: (get last-claim-block staker-info),
        total-claimed: (get total-rewards-claimed staker-info),
        current-rate: (var-get rewards-per-block)
    })
)

;; Get staking statistics for a user
(define-read-only (get-staking-stats (user principal))
    (let (
        (staker-info (get-staker-details user))
    )
    {
        current-stake: (get staked-amount staker-info),
        lifetime-staked: (get total-staked-lifetime staker-info),
        lifetime-unstaked: (get total-unstaked-lifetime staker-info),
        total-claims: (get claim-count staker-info),
        total-stake-actions: (get stake-count staker-info)
    })
)

;; Get reward rate information
(define-read-only (get-reward-info)
    {
        rewards-per-block: (var-get rewards-per-block),
        total-rewards-accumulated: (var-get total-rewards-accumulated),
        last-update-block: (var-get last-update-block)
    }
)

;; Get user reward history for a specific range
(define-read-only (get-user-reward-history (user principal) (start-id uint) (end-id uint))
    (let (
        (user-claim-count (get claim-count (get-staker-details user)))
    )
    (asserts! (>= user-claim-count start-id) ERR_INVALID_INDEX)
    (asserts! (>= end-id start-id) ERR_INVALID_INDEX)
    (asserts! (>= user-claim-count end-id) ERR_INVALID_INDEX)

    (ok {
        claims: (map-get? rewards-history { user: user, claim-id: end-id }),
        total-claims: user-claim-count
    }))
)

(define-read-only (get-staker-details (staker principal))
    (default-to 
        {
            staked-amount: u0,
            reward-debt: u0,
            last-claim-block: u0,
            total-staked-lifetime: u0,
            total-unstaked-lifetime: u0,
            total-rewards-claimed: u0,
            stake-count: u0,
            claim-count: u0
        }
        (map-get? staker-details staker)
    )
)

(define-read-only (get-stake-action-by-id (user principal) (action-id uint))
    (map-get? staking-history { user: user, action-id: action-id })
)

(define-read-only (get-reward-claim-by-id (user principal) (claim-id uint))
    (map-get? rewards-history { user: user, claim-id: claim-id })
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

;; Enhanced Private Functions
(define-private (record-stake-action (user principal) (amount uint) (action-type (string-ascii 10)))
    (let (
        (action-id (var-get total-stake-actions))
        (staker-info (get-staker-details user))
    )
    (map-set staking-history
        { user: user, action-id: action-id }
        {
            action-type: action-type,
            amount: amount,
            block-height: block-height,
            timestamp: (unwrap-panic (get-block-info? time block-height))
        }
    )
    (var-set total-stake-actions (+ action-id u1))
    (map-set staker-details
        user
        (merge staker-info
            {
                stake-count: (+ (get stake-count staker-info) u1)
            }
        )
    )
    )
)

(define-private (record-reward-claim (user principal) (amount uint))
    (let (
        (claim-id (var-get total-reward-claims))
        (staker-info (get-staker-details user))
    )
    (map-set rewards-history
        { user: user, claim-id: claim-id }
        {
            amount: amount,
            block-height: block-height,
            timestamp: (unwrap-panic (get-block-info? time block-height))
        }
    )
    (var-set total-reward-claims (+ claim-id u1))
    (map-set staker-details
        user
        (merge staker-info
            {
                claim-count: (+ (get claim-count staker-info) u1),
                total-rewards-claimed: (+ (get total-rewards-claimed staker-info) amount)
            }
        )
    )
    )
)

;; Enhanced Public Functions
(define-public (stake-tokens (amount uint))
    (let (
        (staker tx-sender) 
        (current-rewards-per-share (calculate-rewards-per-share))    
        (staker-info (get-staker-details staker))                    
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (ft-transfer? staked-token amount staker (as-contract tx-sender))) 

    (update-rewards)

    (map-set staker-details
        staker
        (merge staker-info
            {
                staked-amount: (+ (get staked-amount staker-info) amount),
                reward-debt: (/
                    (* (+ (get staked-amount staker-info) amount) current-rewards-per-share)
                    u1000000
                ),
                last-claim-block: block-height,
                total-staked-lifetime: (+ (get total-staked-lifetime staker-info) amount)
            }
        )
    )

    (var-set total-tokens-staked (+ (var-get total-tokens-staked) amount))
    (record-stake-action staker amount "stake")
    (ok true))
)

(define-public (unstake-tokens (amount uint))
    (let (
        (staker tx-sender)
        (staker-info (get-staker-details staker))
        (current-staked-amount (get staked-amount staker-info))       
    )
    (asserts! (>= current-staked-amount amount) ERR_INSUFFICIENT_BALANCE)

    (try! (claim-rewards))

    (try! (as-contract (ft-transfer? staked-token amount (as-contract tx-sender) staker)))

    (map-set staker-details
        staker
        (merge staker-info
            {
                staked-amount: (- current-staked-amount amount),
                reward-debt: (/
                    (* (- current-staked-amount amount) (calculate-rewards-per-share))
                    u1000000
                ),
                last-claim-block: block-height,
                total-unstaked-lifetime: (+ (get total-unstaked-lifetime staker-info) amount)
            }
        )
    )

    (var-set total-tokens-staked (- (var-get total-tokens-staked) amount))
    (record-stake-action staker amount "unstake")
    (ok true))
)

(define-public (claim-rewards)
    (let (
        (staker tx-sender)
        (pending (calculate-pending-reward staker))                    
        (current-rewards-per-share (calculate-rewards-per-share))       
    )
    (asserts! (> pending u0) ERR_NO_STAKE)

    (update-rewards)

    (try! (as-contract (ft-mint? reward-token pending staker)))

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

    (map-set pending-rewards staker u0)
    (record-reward-claim staker pending)
    (ok true))
)

;; Admin Functions remain the same
(define-public (set-rewards-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (asserts! (> new-rate u0) ERR_INVALID_AMOUNT)
        (var-set rewards-per-block new-rate)
        (ok true))
)

(define-public (emergency-withdraw)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
        (let (
            (stake-balance (ft-get-balance staked-token (as-contract tx-sender)))
            (reward-balance (ft-get-balance reward-token (as-contract tx-sender)))
        )
        (try! (as-contract (ft-transfer? staked-token stake-balance (as-contract tx-sender) (var-get contract-owner))))
        (try! (as-contract (ft-transfer? reward-token reward-balance (as-contract tx-sender) (var-get contract-owner))))
        (ok true)))
)

(define-private (update-rewards)
    (let (
        (current-rewards-per-share (calculate-rewards-per-share))    
    )
    (var-set total-rewards-accumulated current-rewards-per-share)
    (var-set last-update-block block-height))
)
