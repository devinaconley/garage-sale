// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {GarageSale} from "../src/GarageSale.sol";

contract ConfigurationTest is Test {
    GarageSale gs;

    function setUp() public {
        gs = new GarageSale();
    }

    function test_OfferPrice() public {
        gs.setOffer(1e14); // 0.0001
        assertEq(gs.offer(), 1e14);
    }

    function test_MinAuctionPrice() public {
        gs.setOffer(1e15); // 0.001
        assertEq(gs.offer(), 1e15);
    }

    function test_MaxAuctionPrice() public {
        gs.setOffer(1e17); // 0.1
        assertEq(gs.offer(), 1e17);
    }

    function testFuzz_SetDuration(uint256 x) public {
        gs.setDuration(x);
        assertEq(gs.duration(), x);
    }

    function test_CollectionWhitelist() public {
        address tkn = address(12345);
        gs.setCollection(tkn, true);
        assertEq(gs.collections(tkn), true);
    }
}
