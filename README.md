## Eoracle Solidity Home Assignment
## Overview
This contract manages staking functionality within a system, including registration, configuration management, staking, unstaking, and slashing mechanisms.
### Assumptions
- each staker holds only one role
- smart contract will not be used after year 2106 (uint32 is used to store the timestamp)

## Usage

### Setup
Install [Foundry](https://book.getfoundry.sh/getting-started/installation) and [GNU Make](https://www.gnu.org/software/make/)
```shell
$ make install
```

### Build

```shell
$ make build
```

### Test

```shell
$ make test
```

### Deploy
#### Anvil
```shell
$ make deploy-anvil contract=StakeManager
```
#### Testnet
create .env file, add `RPC_URL` and `PRIVATE_KEY` variables for your network
```shell
$ make deploy contract=StakeManager
```
# StakeManager
**Inherits:**
[IStakeManager](/src/IStakeManager.sol/interface.IStakeManager.md), ReentrancyGuardUpgradeable, UUPSUpgradeable, AccessControlUpgradeable


## State Variables
### ADMIN_ROLE

```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
```


### registrationWaitTime

```solidity
uint32 public registrationWaitTime;
```


### registrationDepositAmount

```solidity
uint224 public registrationDepositAmount;
```


### amountSlashed

```solidity
uint256 public amountSlashed;
```


### addressToStakerInfo

```solidity
mapping(address => StakerInfo) public addressToStakerInfo;
```


## Functions
### constructor


```solidity
constructor();
```

### initialize

*Contract initializer*


```solidity
function initialize() public initializer;
```

### setConfiguration

*Allows an admin to set the configuration of the staking contract.
Caller must have ADMIN_ROLE.
Emits ConfigurationUpdated event.*


```solidity
function setConfiguration(uint224 amount, uint32 time) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint224`|Initial registration deposit amount in wei.|
|`time`|`uint32`|The duration a staker must wait after initiating registration.|


### register

*Allows an account to register as a staker.
Emits Registered event.*


```solidity
function register() external payable;
```

### unregister

*Allows a registered staker to unregister and exit the staking system.
Returns total staked amount to the user and removes registration. Reverts if `registrationWaitTime` has not passed.
Emits Unregistered event*


```solidity
function unregister() external nonReentrant;
```

### stake

*Allows registered stakers to stake ether into the contract.
Emits Staked event.*


```solidity
function stake() external payable;
```

### unstake

*Allows registered stakers to unstake their ether from the contract.
Reverts if `registrationWaitTime` has not passed.
Emits Unstaked event.*


```solidity
function unstake(uint224 amount) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint224`|The amount of ether to unstake|


### slash

*Allows an admin to slash a portion of the staked ether of a given staker.
Emits Slashed event.*


```solidity
function slash(address staker, uint224 amount) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`staker`|`address`|The address of the staker to be slashed.|
|`amount`|`uint224`|The amount of ether to be slashed from the staker.|


### withdraw

*Allows an admin to withdraw slashed funds from the contract.
Emits Withdrawn event.*


```solidity
function withdraw(uint256 amount) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of ether to be withdrawn.|


### _authorizeUpgrade

*This function is called before contract upgrade to ensure user is authorized to do so*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyAdmin;
```

### onlyAdmin


```solidity
modifier onlyAdmin();
```

## Events
### ConfigurationUpdated

```solidity
event ConfigurationUpdated(uint224 indexed registrationDepositAmount, uint32 indexed registrationWaitTime);
```

### Registered

```solidity
event Registered(address indexed staker, uint256 indexed amount);
```

### Unregistered

```solidity
event Unregistered(address indexed staker, uint256 indexed amount);
```

### Staked

```solidity
event Staked(address indexed staker, uint256 indexed amount);
```

### Unstaked

```solidity
event Unstaked(address indexed staker, uint256 indexed amount);
```

### Slashed

```solidity
event Slashed(address indexed staker, uint256 indexed amount);
```

### Withdrawn

```solidity
event Withdrawn(address indexed admin, uint256 indexed amount);
```

## Errors
### StakerIsNotRegistered

```solidity
error StakerIsNotRegistered();
```

### StakerIsAlreadyRegistered

```solidity
error StakerIsAlreadyRegistered();
```

### RegistrationDepositIsNotEnough

```solidity
error RegistrationDepositIsNotEnough();
```

### FailedToSendEther

```solidity
error FailedToSendEther();
```

### StakeAmountIsZero

```solidity
error StakeAmountIsZero();
```

### RegistrationWaitTimeHasNotPassed

```solidity
error RegistrationWaitTimeHasNotPassed();
```

### StakedAmountIsLessThenSlashAmount

```solidity
error StakedAmountIsLessThenSlashAmount();
```

### UserIsNotAdmin

```solidity
error UserIsNotAdmin();
```

### NotEnoughFunds

```solidity
error NotEnoughFunds();
```

## Structs
### StakerInfo

```solidity
struct StakerInfo {
    uint32 registrationTime;
    uint224 stakedAmount;
}
```

