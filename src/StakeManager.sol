// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ReentrancyGuardUpgradeable} from  "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./IStakeManager.sol";

contract StakeManager is IStakeManager, ReentrancyGuardUpgradeable, UUPSUpgradeable, AccessControlUpgradeable {
    // Structs
    struct StakerInfo {
        uint32 registrationTime;
        uint224 stakedAmount;
    }
    // Constants
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Public variables
    uint32 public registrationWaitTime;
    uint224 public registrationDepositAmount;
    uint256 public amountSlashed;
    mapping(address => StakerInfo) public addressToStakerInfo;

    //  Events 
    event ConfigurationUpdated(uint224 indexed registrationDepositAmount, uint32 indexed registrationWaitTime);
    event Registered(address indexed staker, uint256 indexed amount);
    event Unregistered(address indexed staker, uint256 indexed amount);
    event Staked(address indexed staker, uint256 indexed amount);
    event Unstaked(address indexed staker, uint256 indexed amount);
    event Slashed(address indexed staker, uint256 indexed amount);
    event Withdrawn(address indexed admin, uint256 indexed amount);

    //  Errors 
    error StakerIsNotRegistered();
    error StakerIsAlreadyRegistered();
    error RegistrationDepositIsNotEnough();
    error FailedToSendEther();
    error StakeAmountIsZero();
    error RegistrationWaitTimeHasNotPassed();
    error StakedAmountIsLessThenSlashAmount();
    error UserIsNotAdmin();
    error NotEnoughFunds();

    constructor() {
        _disableInitializers(); 
    }

    /**
    * @dev Contract initializer
    */
    function initialize() public initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
    * @dev Allows an admin to set the configuration of the staking contract.
    * Caller must have ADMIN_ROLE.
    * Emits ConfigurationUpdated event.
    * @param amount Initial registration deposit amount in wei.
    * @param time The duration a staker must wait after initiating registration.
    */
    function setConfiguration(uint224 amount, uint32 time) external onlyAdmin {
        registrationDepositAmount = amount;
        registrationWaitTime = time;
        emit ConfigurationUpdated(registrationDepositAmount, registrationWaitTime);
    }

    /**
    * @dev Allows an account to register as a staker.
    * Emits Registered event.
    */
    function register() external payable {
        StakerInfo storage stakerInfo = addressToStakerInfo[msg.sender];

        if (stakerInfo.registrationTime > 0) {
            revert StakerIsAlreadyRegistered();
        }
        if (msg.value < registrationDepositAmount) {
            revert RegistrationDepositIsNotEnough();
        }
        addressToStakerInfo[msg.sender].registrationTime = uint32(block.timestamp);
        addressToStakerInfo[msg.sender].stakedAmount = uint224(msg.value);

        emit Registered(msg.sender, msg.value);
    }

    /**
    * @dev Allows a registered staker to unregister and exit the staking system.
    * Returns total staked amount to the user and removes registration. Reverts if `registrationWaitTime` has not passed.
    * Emits Unregistered event
    */
    function unregister() external nonReentrant {
        StakerInfo memory stakerInfo = addressToStakerInfo[msg.sender];
        if (stakerInfo.registrationTime == 0) {
            revert StakerIsNotRegistered();
        }
        if (stakerInfo.registrationTime + registrationWaitTime > block.timestamp) {
            revert RegistrationWaitTimeHasNotPassed();
        }

        delete addressToStakerInfo[msg.sender];
        
        if (stakerInfo.stakedAmount > 0) {
            (bool sent,) = msg.sender.call{value: stakerInfo.stakedAmount}("");
            if(!sent) revert FailedToSendEther();
        }
        emit Unregistered(msg.sender, stakerInfo.stakedAmount);
    }

    /**
    * @dev Allows registered stakers to stake ether into the contract.
    * Emits Staked event.
    */
    function stake() external payable {
        if (msg.value == 0) {
            revert StakeAmountIsZero();
        }
        StakerInfo memory stakerInfo = addressToStakerInfo[msg.sender];
        if (stakerInfo.registrationTime == 0) {
            revert StakerIsNotRegistered();
        }
        addressToStakerInfo[msg.sender].stakedAmount += uint224(msg.value);

        emit Staked(msg.sender, msg.value);
    }

    /**
    * @dev Allows registered stakers to unstake their ether from the contract.
    * Reverts if `registrationWaitTime` has not passed.
    * Emits Unstaked event.
    * @param amount The amount of ether to unstake
    */
    function unstake(uint224 amount) external nonReentrant {
        StakerInfo memory stakerInfo = addressToStakerInfo[msg.sender];
        if (stakerInfo.registrationTime == 0) {
            revert StakerIsNotRegistered();
        }
        if(stakerInfo.stakedAmount < amount) {
            revert NotEnoughFunds();
        }
        if (stakerInfo.registrationTime + registrationWaitTime > block.timestamp) {
            revert RegistrationWaitTimeHasNotPassed();
        }
        addressToStakerInfo[msg.sender].stakedAmount -= amount;
        
        (bool sent,) = msg.sender.call{value: amount}("");
        if(!sent) revert FailedToSendEther();

        emit Unstaked(msg.sender, amount);
    }

    /**
    * @dev Allows an admin to slash a portion of the staked ether of a given staker.
    * Emits Slashed event.
    * @param staker The address of the staker to be slashed.
    * @param amount The amount of ether to be slashed from the staker.
    */
    function slash(address staker, uint224 amount) external onlyAdmin {
        if(addressToStakerInfo[staker].stakedAmount < amount) {
            revert StakedAmountIsLessThenSlashAmount();
        }
        addressToStakerInfo[staker].stakedAmount -= amount;
        amountSlashed += amount;

        emit Slashed(staker, amount);
    }

    /**
    * @dev Allows an admin to withdraw slashed funds from the contract.
    * Emits Withdrawn event.
    * @param amount The amount of ether to be withdrawn.
    */
    function withdraw(uint256 amount) external onlyAdmin {
        if(amount > amountSlashed) {
            revert NotEnoughFunds();
        }
        (bool sent,) = msg.sender.call{value: amount}("");
        if(!sent) revert FailedToSendEther();
        amountSlashed -= amount;

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev This function is called before contract upgrade to ensure user is authorized to do so
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) {
            revert UserIsNotAdmin();
        }
        _;
    }
}
