// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {GarageSale} from "../src/GarageSale.sol";
import {TestERC721} from "../src/test/ERC721.sol";
import {TestERC1155} from "../src/test/ERC1155.sol";

contract AuctionTest is Test {
    GarageSale gs;
    TestERC721 erc721;
    TestERC1155 erc1155;
    address alice;
    address bob;

    function setUp() public {
        gs = new GarageSale();
        erc721 = new TestERC721("TestERC721", "NFT");
        erc1155 = new TestERC1155();
        alice = address(0xa11ce);
        bob = address(0x808);

        vm.deal(address(gs), 1e18);
        gs.setToken(address(erc721), 1);
        gs.setToken(address(erc1155), 2);

        erc721.mint(alice, 5);
        erc721.mint(bob, 3);
        erc1155.mint(alice, 1, 5000);
        erc1155.mint(alice, 2, 1);
        erc1155.mint(alice, 3, 42);
        erc1155.mint(bob, 1, 3000);

        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 5);
        vm.prank(bob);
        erc721.safeTransferFrom(bob, address(gs), 7);
        vm.prank(alice);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 3;
        ids[1] = 1;
        uint256[] memory values = new uint256[](2);
        values[0] = 42;
        values[1] = 3000;
        erc1155.safeBatchTransferFrom(alice, address(gs), ids, values, "");
        vm.prank(bob);
        erc1155.safeTransferFrom(bob, address(gs), 1, 1000, "");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 2);
        vm.prank(bob);
        erc721.safeTransferFrom(bob, address(gs), 6);
        vm.prank(bob);
        erc721.safeTransferFrom(bob, address(gs), 8);

        // inventory: [erc721:5, erc721:7, erc1155:3(42), erc1155:1(4000), erc721#2, erc721#6, erc721#8]
    }

    function test_Seed() public {
        uint256 t0 = 1702629000; // dec 15, 830a utc
        bytes32 seed = keccak256(abi.encodePacked(t0));
        vm.warp(t0);
        assertEq(gs.seed(), seed);

        vm.warp(1702629005); // 5 seconds later
        assertEq(gs.seed(), seed);

        vm.warp(1702629600); // 10 minutes later
        assertEq(gs.seed(), seed);

        vm.warp(1702629901); // 14 minutes and 59 seconds later
        assertNotEq(gs.seed(), seed);

        vm.warp(1702629901); // 15 minutes and one second later
        assertNotEq(gs.seed(), seed);
    }

    function test_SeedTurnover() public {
        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        bytes32 s0 = keccak256(abi.encodePacked(t0));
        vm.warp(t0);
        assertEq(gs.seed(), s0);

        vm.warp(1735675230);
        assertEq(gs.seed(), s0);

        vm.warp(1735676095);
        assertEq(gs.seed(), s0);

        uint256 t1 = 1735676100; // 2024/12/31 815p utc
        bytes32 s1 = keccak256(abi.encodePacked(t1));
        vm.warp(t1);
        assertEq(gs.seed(), s1);

        vm.warp(1735676160);
        assertEq(gs.seed(), s1);

        assertNotEq(s0, s1);
    }

    function test_SeedDurationChanged() public {
        gs.setAuction(1e15, 1e17, 3600);

        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        bytes32 s0 = keccak256(abi.encodePacked(t0));
        vm.warp(t0);
        assertEq(gs.seed(), s0);

        vm.warp(1735678790);
        assertEq(gs.seed(), s0);

        uint256 t1 = 1735678800; // 2024/12/31 9p utc
        bytes32 s1 = keccak256(abi.encodePacked(t1));
        vm.warp(t1);
        assertEq(gs.seed(), s1);

        vm.warp(1735678815);
        assertEq(gs.seed(), s1);

        assertNotEq(s0, s1);
    }
}
