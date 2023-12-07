// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import "../src/GarageSale.sol";

contract GarageSaleDeploy is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        GarageSale gs = new GarageSale();
        vm.stopBroadcast();
    }
}
