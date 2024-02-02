// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {StakeManager} from "../src/StakeManager.sol";
import {StakeManagerV2} from "../src/StakeManagerV2.sol";


contract UpgradeStakeManager is Script {
    function run() external returns (address) {
        address proxyAddress = vm.envAddress("STAKE_MANAGER_PROXY");
        vm.startBroadcast();
        StakeManagerV2 newStakeManager = new StakeManagerV2();
        vm.stopBroadcast();
        address proxy = upgradeStakeManager(proxyAddress, address(newStakeManager));
        return proxy;
    }

    function upgradeStakeManager(address proxyAddress, address newStakeManager) public returns (address) {
        vm.startBroadcast();
        StakeManager proxy = StakeManager(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newStakeManager), "");
        vm.stopBroadcast();
        return address(proxy);
    }
}