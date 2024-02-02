// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { StakeManager } from "../src/StakeManager.sol";
import { StakeManagerV2 } from "../src/StakeManagerV2.sol";

contract StakeManagerTest is StdCheats, Test {
    StakeManager internal stakeManager;
    uint224 internal registrationDepositAmount = 1 ether;
    uint32 internal registrationWaitTime = 1 days;

    event ConfigurationUpdated(uint224 indexed registrationDepositAmount, uint32 indexed registrationWaitTime);
    event Registered(address indexed staker, uint256 indexed amount);
    event Unregistered(address indexed staker, uint256 indexed amount);
    event Staked(address indexed staker, uint256 indexed amount);
    event Unstaked(address indexed staker, uint256 indexed amount);
    event Slashed(address indexed staker, uint256 indexed amount);
    event Withdrawn(address indexed admin, uint256 indexed amount);

    error StakerIsNotRegistered();
    error StakerIsAlreadyRegistered();
    error RegistrationDepositIsNotEnough();
    error FailedToSendEther();
    error StakeAmountIsZero();
    error RegistrationWaitTimeHasNotPassed();
    error StakedAmountIsLessThenSlashAmount();
    error UserIsNotAdmin();
    error NotEnoughFunds();

    receive() external payable { }

    function setUp() public virtual {
        StakeManager sm = new StakeManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(sm), abi.encodeWithSelector(sm.initialize.selector));
        stakeManager = StakeManager(address(proxy));

        stakeManager.setConfiguration(registrationDepositAmount, registrationWaitTime);
    }

    function test_Upgrade() public {
        uint256 expectedValue = 42;
        StakeManagerV2 newStakeManager = new StakeManagerV2();
        stakeManager.upgradeToAndCall(address(newStakeManager), "");
        assertEq(StakeManagerV2(address(stakeManager)).NEW_VAR(), expectedValue);
    }

    function test_RevertWhen_Upgrade_CallerNotAdmin(address randomUser) public {
        vm.assume(randomUser != address(this));
        StakeManagerV2 newStakeManager = new StakeManagerV2();
        console2.log(randomUser, address(this));
        vm.expectRevert(UserIsNotAdmin.selector);
        vm.prank(randomUser);
        stakeManager.upgradeToAndCall(address(newStakeManager), "");
    }

    function test_SetConfiguration(uint224 amount, uint32 time) public {
        vm.expectEmit(true, true, true, false);
        emit ConfigurationUpdated(amount, time);
        stakeManager.setConfiguration(amount, time);
        assertEq(stakeManager.registrationDepositAmount(), amount);
        assertEq(stakeManager.registrationWaitTime(), time);
    }

    function test_RevertWhen_SetConfiguration_CallerNotAdmin(address randomUser) public {
        vm.assume(randomUser != address(this));
        vm.expectRevert(abi.encodeWithSelector(UserIsNotAdmin.selector));
        vm.prank(randomUser);
        stakeManager.setConfiguration(0, 0);
    }

    function test_Register() public payable {
        vm.expectEmit(true, true, true, true);
        emit Registered(address(this), registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        assertEq(address(stakeManager).balance, registrationDepositAmount);
        (uint32 registrationTime, uint224 stakedAmount) = stakeManager.addressToStakerInfo(address(this));
        assertEq(registrationTime, uint32(block.timestamp));
        assertEq(stakedAmount, registrationDepositAmount);
    }

    function test_RevertWhen_Register_DepositIsNotEnough(uint256 amount) public payable {
        vm.assume(amount < registrationDepositAmount);
        vm.expectRevert(RegistrationDepositIsNotEnough.selector);
        stakeManager.register{ value: amount }();
    }

    function test_Unregister() public payable {
        stakeManager.register{ value: registrationDepositAmount }();
        uint256 balanceBefore = address(this).balance;
        vm.warp(block.timestamp + registrationWaitTime);
        vm.expectEmit(true, true, true, true);
        emit Unregistered(address(this), registrationDepositAmount);
        stakeManager.unregister();
        assertEq(address(this).balance, balanceBefore + registrationDepositAmount);
        (uint32 registrationTime, uint224 stakedAmount) = stakeManager.addressToStakerInfo(address(this));
        assertEq(registrationTime, 0);
        assertEq(stakedAmount, 0);
    }

    function test_RevertWhen_Unregister_WaitTimeHasNotPassed(uint32 time) public payable {
        vm.assume(time < registrationWaitTime);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(RegistrationWaitTimeHasNotPassed.selector);
        stakeManager.unregister();
    }

    function test_RevertWhen_Unregister_StakerIsNotRegistered(address staker, address sender) public payable {
        hoax(staker, registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.prank(sender);
        vm.expectRevert(StakerIsNotRegistered.selector);
        stakeManager.unregister();
    }

    function test_Stake(uint256 amount) public payable {
        stakeManager.register{ value: registrationDepositAmount }();
        vm.assume(amount <= address(this).balance && amount > 0);
        vm.expectEmit(true, true, true, true);
        emit Staked(address(this), amount);
        stakeManager.stake{ value: amount }();
        (, uint224 stakedAmount) = stakeManager.addressToStakerInfo(address(this));
        assertEq(stakedAmount, registrationDepositAmount + amount);
    }

    function test_RevertWhen_Stake_StakerIsNotRegistered(address staker, address sender, uint224 amount) public payable {
        vm.assume(staker != sender);
        vm.assume(amount < type(uint224).max - registrationDepositAmount && amount > 0);
        hoax(staker, registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();

        hoax(sender, amount);
        vm.expectRevert(StakerIsNotRegistered.selector);
        stakeManager.stake{ value: amount }();
    }

    function test_RevertWhen_Stake_AmountIsZero() public payable {
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(StakeAmountIsZero.selector);
        stakeManager.stake{ value: 0 }();
    }

    function test_Unstake() public payable {
        stakeManager.register{ value: registrationDepositAmount }();
        uint256 stakeAmount = 1 ether;
        stakeManager.stake{ value: stakeAmount }();
        uint256 balanceBefore = address(this).balance;
        vm.warp(block.timestamp + registrationWaitTime);
        uint224 unstakeAmount = 1 ether;
        vm.expectEmit(true, true, true, true);
        emit Unstaked(address(this), unstakeAmount);
        stakeManager.unstake(unstakeAmount);
        assertEq(address(this).balance, balanceBefore + unstakeAmount);
        (, uint224 stakedAmount) = stakeManager.addressToStakerInfo(address(this));
        assertEq(stakedAmount, registrationDepositAmount + stakeAmount - unstakeAmount);
    }

    function test_RevertWhen_Unstake_WaitTimeHasNotPassed(uint32 time) public payable {
        vm.assume(time < registrationWaitTime);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(RegistrationWaitTimeHasNotPassed.selector);
        stakeManager.unstake(registrationDepositAmount);
    }

    function test_RevertWhen_Unstake_NotEnoughFunds(uint224 amount) public payable {
        vm.assume(amount > registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.warp(block.timestamp + registrationWaitTime);
        vm.expectRevert(NotEnoughFunds.selector);
        stakeManager.unstake(amount);
    }

    function test_RevertWhen_Unstake_StakerIsNotRegistered(address staker, address sender) public payable {
        vm.assume(staker != sender);
        hoax(staker, registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(StakerIsNotRegistered.selector);
        vm.prank(sender);
        stakeManager.unstake(registrationDepositAmount);
    }

    function test_Slash(address staker, uint224 amount) public payable {
        vm.assume(amount <= registrationDepositAmount);
        vm.assume(staker != address(this));
        hoax(staker, registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectEmit(true, true, true, true);
        emit Slashed(staker, amount);
        stakeManager.slash(staker, amount);
        (, uint224 stakedAmount) = stakeManager.addressToStakerInfo(staker);
        assertEq(stakedAmount, registrationDepositAmount - amount);
    }

    function test_RevertWhen_Slash_CallerNotAdmin(address sender) public payable {
        vm.assume(sender != address(this));
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(UserIsNotAdmin.selector);
        vm.prank(sender);
        stakeManager.slash(address(this), registrationDepositAmount);
    }

    function test_revertWhen_Slash_AmountIsMoreStaked(uint224 amount) public payable {
        vm.assume(amount > registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(StakedAmountIsLessThenSlashAmount.selector);
        stakeManager.slash(address(this), amount);
    }

    function test_Withdraw(uint224 amount) public payable {
        vm.assume(amount <= registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        stakeManager.slash(address(this), registrationDepositAmount);
        uint256 balanceBefore = address(this).balance;
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(address(this), amount);
        stakeManager.withdraw(amount);
        assertEq(address(this).balance, balanceBefore + amount);
    }

    function test_revertWhen_Withdraw_AmountIsMoreSlashed(uint224 amount) public payable {
        vm.assume(amount > registrationDepositAmount);
        stakeManager.register{ value: registrationDepositAmount }();
        stakeManager.slash(address(this), registrationDepositAmount);
        vm.expectRevert(NotEnoughFunds.selector);
        stakeManager.withdraw(amount);
    }

    function test_RevertWhen_Withdraw_CallerNotAdmin(address sender) public payable {
        vm.assume(sender != address(this));
        stakeManager.register{ value: registrationDepositAmount }();
        vm.expectRevert(UserIsNotAdmin.selector);
        vm.prank(sender);
        stakeManager.withdraw(registrationDepositAmount);
    }
}
