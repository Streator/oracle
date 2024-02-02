// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {StakeManager} from "../src/StakeManager.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployStakeManager is Script {
    function run() external returns (address) {
        address proxy = deployStakeManager();
        return proxy;
    }

    function deployStakeManager() public returns (address) {
        vm.startBroadcast();
        StakeManager sm = new StakeManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(sm), abi.encodeWithSelector(sm.initialize.selector));
        vm.stopBroadcast();
        return address(proxy);
    }
}
