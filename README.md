# Solidity-Staking

# lending

## setup 

### open terminal & type:

`anvil`

this gives you a local testnet.

```
                             _   _
                            (_) | |
      __ _   _ __   __   __  _  | |
     / _` | | '_ \  \ \ / / | | | |
    | (_| | | | | |  \ V /  | | | |
     \__,_| |_| |_|   \_/   |_| |_|

    0.1.0 (c5dd9a6 2023-02-26T00:12:26.731321Z)
    https://github.com/foundry-rs/foundry

Available Accounts
==================

(0) "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" (10000 ETH)
(1) "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" (10000 ETH)
```

### open vscode and type:

`yarn hardhat run scripts/deployLendingPool --network localhost`

this will deploy it to the anvil testnet:

```
--------------- Stage 1: Deploying Contracts ---------------
Deploying contracts with the following addresses:
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Player1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Player2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
Timelock deployed to: 0x582957C7a35CDfeAAD1Ca4b87AE03913eAAd0Be0
MockToken deployed to: 0x63ecE4C05B8fB272D16844E96702Ea2f26370982
Tokens minted for Player1 and Player2.

--------------- Stage 2: Deploying GovernorContract ---------------
GovernorContract deployed to: 0x3576293Ba6Adacba1A81397db889558Dd91A8519
Roles assigned to GovernorContract.

--------------- Stage 3: Deploying LendingPool ---------------
LendingPool deployed to: 0x645B0f55268eF561176f3247D06d0b7742f79819

--------------- Stage 4: Creating Proposal ---------------
Proposal ID: 96645939421689743423546212532842034144634098206533575751212793009354625974599
Description: Mint Tokens Proposal
Proposer: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
For Votes: 0
Against Votes: 0
Executed: false

--------------- Stage 5: Voting on Proposal ---------------
Proposal ID: 96645939421689743423546212532842034144634098206533575751212793009354625974599
Description: Mint Tokens Proposal
Proposer: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
For Votes: 1100000000000000000000
Against Votes: 0
Executed: false
Current block number: 1006

--------------- Stage 6: Executing Proposal ---------------
current state: 1
Queuing operation...
Balance of player1: 1100.0 tokens
current state: 7
Execution of proposal completed.

--------------- Stage 7: Finalizing ---------------
Voting count for votes now: BigNumber { value: "0" }
Voting count against votes now: BigNumber { value: "0" }
Deployment and proposal creation completed successfully.
Balance of player1: 1223.0 tokens
current state: 7
Proposal ID: 96645939421689743423546212532842034144634098206533575751212793009354625974599
Description: Mint Tokens Proposal
Proposer: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
For Votes: 1100000000000000000000
Against Votes: 0
Executed: true
✨  Done in 18.73s.
```

# Staking

## setup 

### open terminal & type:

`npx hardhat test ./test/staking/staking.challenge.js `

output:

```
Compiled 20 Solidity files successfully


  Staking Contract
    ✔ Should have deposited correctly
Current time before adjustment: 1720014415
    ✔ Should have withdrawn correctly
Current time before adjustment: 1720024419
final reward: 500100
    ✔ Should distribute rewards correctly in ETH
Current time before adjustment: 1720029426
final reward: 77079
final reward: 231282
final reward: 154218
final reward: 38562
BigNumber { value: "77079" }
BigNumber { value: "231282" }
BigNumber { value: "154218" }
BigNumber { value: "38562" }
BigNumber { value: "200000000000" }
    ✔ Should distribute rewards correctly among stakers (96ms)
Current time before adjustment: 1720034435
    ✔ Should transfer tokens correctly (46ms)
Current time before adjustment: 1720044442
    ✔ Should transfer tokens correctly (59ms)
    ✔ Should fail to withdraw before time period
final reward: 0
    ✔ Should fail to claim reward without staking
    ✔ Should fail to deposit more than maximum stake amount
    ✔ Should fail to deposit less than minimum stake amount
    ✔ Should fail to withdraw more than staked amount
final reward: 0
    ✔ Should prevent unauthorized access to reward claim
    ✔ Should correctly handle multiple deposits and withdrawals
BigNumber { value: "250000000000000000" }
    ✔ Should adjust minimum and maximum stake amounts based on ETH price
BigNumber { value: "0" }
1500000000000000000
10
BigNumber { value: "150000000000000000" }
    ✔ Should correctly handle emergecyWithdrawAll (40ms)
swag BigNumber { value: "9984844872608320489433" }
swag2 BigNumber { value: "1500000000000000000" }
1500000000000000000
10
swag BigNumber { value: "9986194743561782985587" }
swag2 BigNumber { value: "150000000000000000" }
    ✔ Should correctly handle emergencyWithdrawAll and apply penalty (41ms)


  16 passing (3s)
```






