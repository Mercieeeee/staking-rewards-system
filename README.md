# Staking Rewards Contract (Clarity 2.0)

This project implements a **Staking Rewards Contract** in **Clarity 2.0** for a blockchain-based system. The contract allows users to stake tokens and earn rewards proportionally over time, facilitating yield farming. This README provides a detailed overview of the contract, its features, and how to interact with it.

---

## Table of Contents
1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Smart Contract Details](#smart-contract-details)
   - [Token Definitions](#token-definitions)
   - [Error Constants](#error-constants)
   - [State Variables](#state-variables)
   - [Staker Information](#staker-information)
4. [Contract Functions](#contract-functions)
   - [Read-Only Functions](#read-only-functions)
   - [Public Functions](#public-functions)
   - [Private Functions](#private-functions)
   - [Admin Functions](#admin-functions)
5. [Usage](#usage)
6. [Development Notes](#development-notes)
7. [License](#license)

---

## Overview

The **Staking Rewards Contract** enables users to:
- Stake a fungible token (`staked-token`) to earn rewards.
- Receive rewards in the form of another fungible token (`reward-token`).
- Claim rewards based on the number of tokens staked and the duration of staking.

---

## Key Features

- **Token Staking**: Users can lock tokens in the contract to earn rewards.
- **Reward Calculation**: Rewards are dynamically calculated based on the staking duration and token amount.
- **Claim Rewards**: Users can claim rewards at any time.
- **Unstaking**: Users can unstake tokens while claiming their accrued rewards.
- **Error Handling**: Common errors are predefined for better debugging and user feedback.
- **Reward Rate Adjustments**: Admins can dynamically update the rewards rate for flexibility.
- **Emergency Withdrawals**: Admins can recover all staked and reward tokens in case of emergencies.

---

## Smart Contract Details

### Token Definitions

- `staked-token`: The fungible token users stake.
- `reward-token`: The fungible token used as rewards.

### Error Constants

| Error Code       | Description                              |
|-------------------|------------------------------------------|
| `ERR_NOT_AUTHORIZED (u1001)` | Caller is not authorized for this action. |
| `ERR_INSUFFICIENT_BALANCE (u1002)` | Insufficient balance for unstaking. |
| `ERR_INVALID_AMOUNT (u1003)` | The specified amount is invalid. |
| `ERR_NOT_ACTIVE (u1004)` | Staking is currently disabled. |
| `ERR_NO_STAKE (u1005)` | No staked tokens found for the user. |
| `ERR_ALREADY_CLAIMED (u1006)` | Rewards have already been claimed. |

### State Variables

| Variable                | Description                                     |
|--------------------------|-------------------------------------------------|
| `contract-owner`         | Principal address of the contract owner.        |
| `rewards-per-block`      | Rewards distributed per block (default: `u100`).|
| `last-update-block`      | Last block height rewards were updated.         |
| `total-rewards-accumulated` | Total rewards per share accumulated.          |
| `total-tokens-staked`    | Total tokens currently staked in the contract.  |

### Staker Information

Staker data is managed using the `staker-details` map:
- `staked-amount`: Amount of tokens staked by the user.
- `reward-debt`: Amount of rewards already claimed.
- `last-claim-block`: Block height of the last reward claim.

---

## Contract Functions

### Read-Only Functions

1. **`get-staker-details`**: Retrieves staking details for a given user.
2. **`calculate-pending-reward`**: Calculates the pending rewards for a user.
3. **`calculate-rewards-per-share`**: Computes the rewards accumulated per staked token.

### Public Functions

1. **`stake-tokens`**: Allows users to stake tokens. Updates staking and reward data.
2. **`unstake-tokens`**: Lets users unstake tokens and claim their pending rewards.
3. **`claim-rewards`**: Enables users to claim their accrued rewards without unstaking.

### Private Functions

1. **`update-rewards`**:  
   - Updates the `total-rewards-accumulated` with the current rewards per share.
   - Updates `last-update-block` to the current block height.  
   - Ensures reward calculations remain accurate over time.

### Admin Functions

1. **`set-rewards-rate`**:  
   - Allows the contract owner to update the rewards rate (`rewards-per-block`).  
   - Ensures the new rate is greater than zero for validity.  
   - Throws an error (`ERR_NOT_AUTHORIZED`) if the caller is not the contract owner or (`ERR_INVALID_AMOUNT`) for invalid inputs.

2. **`emergency-withdraw`**:  
   - Allows the contract owner to withdraw all tokens (`staked-token` and `reward-token`) in the contract.  
   - Transfers tokens back to the owner's address.  
   - Ensures only the owner can invoke this function, throwing `ERR_NOT_AUTHORIZED` for unauthorized access.

---

## Usage

### Prerequisites

- **Clarity 2.0 environment**: Ensure you have a blockchain that supports Clarity 2.0.
- **Token contracts**: Deploy fungible tokens for `staked-token` and `reward-token`.

### Steps to Interact

1. **Staking Tokens**:
   - Call `stake-tokens` with the amount you wish to stake.
   - Ensure you have approved the token transfer.

2. **Claiming Rewards**:
   - Call `claim-rewards` to withdraw your rewards without unstaking.

3. **Unstaking Tokens**:
   - Call `unstake-tokens` with the amount you want to withdraw.
   - This will also claim your pending rewards.

---

## Development Notes

### Reward Calculation

Rewards are calculated based on:
1. **Blocks Passed**: Time elapsed since the last reward update.
2. **Staked Tokens**: The number of tokens staked by the user.
3. **Rewards Per Block**: The contract's reward rate.

### Error Handling

- Errors are thrown using `asserts!` statements to ensure safe execution.
- Predefined error codes make debugging easier.

### Updating Rewards

The `update-rewards` logic is embedded in staking and claiming functions to ensure accurate reward distribution.

### Additional Admin and Maintenance Functions

- **Reward Updates**: The `update-rewards` function ensures consistent reward distribution by syncing accumulated rewards and block height.  
- **Safety Measures**: The `emergency-withdraw` function acts as a failsafe for recovering tokens.  
- **Access Control**: Functions like `set-rewards-rate` and `emergency-withdraw` include strict ownership validation to prevent unauthorized actions.

---

## License

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute this contract as per the license terms.

---
