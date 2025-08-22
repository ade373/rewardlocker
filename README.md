# RewardLocker Smart Contract

A Clarity smart contract for managing time-locked STX rewards with dynamic top-up functionality on the Stacks blockchain.

## Features

- **Dynamic Reward Tiers**
  - 20% reward for ≥1000 STX
  - 15% reward for 500-999 STX
  - 10% reward for <500 STX

- **Early Contributor Bonus**
  - Additional 5% bonus for contributions before block height 1000
  - Automatically calculated and added to base rewards

- **Flexible Lock Periods**
  - Default lock period: 30 days (2,592,000 blocks)
  - Customizable lock periods per contributor
  - Lock period extensions on top-ups

## Usage

```clarity
;; Contribute STX and receive rewards
(contract-call? .reward-locker rewardLockerAction "contribute" u1000 tx-sender u0)

;; Claim rewards after lock period
(contract-call? .reward-locker rewardLockerAction "claim" u0 tx-sender u0)

;; Query contributor details
(contract-call? .reward-locker rewardLockerAction "get-contributor" u0 tx-sender u0)
```

## Error Codes

- `ERR-ZERO-AMOUNT (u100)`: Amount must be greater than 0
- `ERR-NOT-CONTRIBUTOR (u101)`: Address not found in contributors
- `ERR-ALREADY-CLAIMED (u102)`: Rewards already claimed
- `ERR-LOCKED (u103)`: Rewards still locked
- `ERR-INSUFFICIENT-REWARD (u104)`: Insufficient reward pool
- `ERR-INVALID-ACTION (u105)`: Invalid action specified

## Events

Events are emitted as prints for:
- Contributions
- Top-ups
- Claims
- 
## License

MIT License
