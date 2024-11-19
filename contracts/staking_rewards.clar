;; staking-rewards.clar
;; Staking Rewards Contract - Clarity 2.0
;; This contract allows users to stake tokens and earn rewards based on their staked amount over time, facilitating yield farming.

;; Token Definitions
(define-fungible-token staked-token)                         	;; The token that users can stake for rewards.
(define-fungible-token reward-token)                         	;; The token that represents the rewards users earn.

;; Error Constants
(define-constant ERR_NOT_AUTHORIZED (err u1001))           	;; Error: Caller is not authorized for this action.
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))     	;; Error: Insufficient balance to complete the unstake.
(define-constant ERR_INVALID_AMOUNT (err u1003))           	;; Error: The specified amount is invalid.
(define-constant ERR_NOT_ACTIVE (err u1004))               	;; Error: Contract is not active for staking.
(define-constant ERR_NO_STAKE (err u1005))                 	;; Error: No staked amount found for this user.
(define-constant ERR_ALREADY_CLAIMED (err u1006))          	;; Error: Rewards have already been claimed.
