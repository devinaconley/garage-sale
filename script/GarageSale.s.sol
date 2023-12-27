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
        bytes32 salt = 0xd7945335d940ea56b1993bc273db27460dce39e5c6f743831ea76041cfbe6c3b; // mined for leading zeros

        vm.startBroadcast();
        GarageSale gs = new GarageSale{salt: salt}(owner);
        vm.stopBroadcast();
    }
}
