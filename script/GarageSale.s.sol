// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import "../src/GarageSale.sol";

contract GarageSaleDeploy is Script {
    function setUp() public {}

    function run() public {
        address owner = 0x55f225153488E9f75213d0BF4b44920f76b7C69c;
        // bytes32 h = keccak256(abi.encodePacked(type(GarageSale).creationCode, abi.encode(owner)));
        // console2.logBytes32(h);
        bytes32 salt = 0x1a50fd5c959a90f8a8764cb1d9e8665d3d68607d56996b41b49b70154206605e; // mined for leading zeros

        vm.startBroadcast();
        GarageSale gs = new GarageSale{salt: salt}(owner);
        vm.stopBroadcast();
    }
}
