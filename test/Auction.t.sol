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
        vm.deal(alice, 1e18);
        vm.deal(bob, 1e18);
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

        // inventory: [erc721:5, erc721:7, erc1155:3(42), erc1155:1(4000), erc721:2, erc721:6, erc721:8]
        gs.bump();
    }

    function test_Seed() public {
        uint256 prev = gs.previous();
        uint256 t0 = 1702629000; // dec 15, 830a utc
        uint256 seed = uint256(keccak256(abi.encodePacked(t0, prev)));
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
        uint256 prev = gs.previous();
        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        uint256 s0 = uint256(keccak256(abi.encodePacked(t0, prev)));
        vm.warp(t0);
        assertEq(gs.seed(), s0);

        vm.warp(1735675230);
        assertEq(gs.seed(), s0);

        vm.warp(1735676095);
        assertEq(gs.seed(), s0);

        uint256 t1 = 1735676100; // 2024/12/31 815p utc
        uint256 s1 = uint256(keccak256(abi.encodePacked(t1, prev)));
        vm.warp(t1);
        assertEq(gs.seed(), s1);

        vm.warp(1735676160);
        assertEq(gs.seed(), s1);

        assertNotEq(s0, s1);
    }

    function test_SeedAuctionChanged() public {
        gs.setAuction(1e15, 1e17, 3600);
        uint256 prev = gs.previous();

        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        uint256 s0 = uint256(keccak256(abi.encodePacked(t0, prev)));
        vm.warp(t0);
        assertEq(gs.seed(), s0);

        vm.warp(1735678790);
        assertEq(gs.seed(), s0);

        uint256 t1 = 1735678800; // 2024/12/31 9p utc
        uint256 s1 = uint256(keccak256(abi.encodePacked(t1, prev)));
        vm.warp(t1);
        assertEq(gs.seed(), s1);

        vm.warp(1735678815);
        assertEq(gs.seed(), s1);

        assertNotEq(s0, s1);
    }

    function test_Price() public {
        uint256 t0 = 1702629000; // dec 15, 830a utc
        vm.warp(t0);
        assertEq(gs.price(), 0.1 ether);

        vm.warp(1702629100); // 100 seconds later
        assertEq(gs.price(), 0.09 ether);

        vm.warp(1702629450); // halfway through auction
        assertEq(gs.price(), 0.055 ether);

        vm.warp(1702629895); // 5 seconds left
        assertEq(gs.price(), 0.0105 ether);
    }

    function test_PriceTurnover() public {
        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        vm.warp(t0);
        assertEq(gs.price(), 0.1 ether);

        vm.warp(t0 + 300); // 300 seconds later
        assertEq(gs.price(), 0.07 ether);

        vm.warp(t0 + 885); // 15 seconds left
        assertEq(gs.price(), 0.0115 ether);

        vm.warp(t0 + 900); // next auction window
        assertEq(gs.price(), 0.1 ether);

        vm.warp(t0 + 930); // 30 seconds in
        assertEq(gs.price(), 0.097 ether);
    }

    function test_PriceAuctionChanged() public {
        gs.setAuction(2e16, 4e16, 3600);

        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        vm.warp(t0);
        assertEq(gs.price(), 0.04 ether);

        vm.warp(t0 + 1800); // 30 minutes later
        assertEq(gs.price(), 0.03 ether);

        vm.warp(t0 + 3540); // 1 minute left
        assertApproxEqAbs(gs.price(), 0.0203333 ether, 1e12);

        vm.warp(t0 + 3780); // next auction window
        assertEq(gs.price(), 0.039 ether);
    }

    function test_Buy() public {
        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 180); // 3 minutes in, price @ 0.082
        uint256 seed = gs.seed();
        // emit log_uint(seed);

        vm.prank(alice);
        gs.buy{value: 0.082 ether}(seed); // expect items: 2, 1, 2(6), 3

        // verify
        assertEq(gs.inventorySize(), 3);
        assertEq(gs.previous(), 3);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(alice, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(7), alice);
        assertEq(erc721.ownerOf(8), alice);
        assertEq(erc1155.balanceOf(alice, 1), 6000); // 2000 already held + 4000 combined in bundle
        assertEq(erc1155.balanceOf(address(gs), 1), 0);

        (address tkn, uint256 id) = gs.inventory(0); // 0th
        assertEq(tkn, address(erc721));
        assertEq(id, 5);
        (tkn, id) = gs.inventory(1); // 6th backfill
        assertEq(tkn, address(erc721));
        assertEq(id, 6);
        (tkn, id) = gs.inventory(2); // 5th backfill
        assertEq(tkn, address(erc721));
        assertEq(id, 2);

        uint256 key = uint256(uint160(address(erc1155)));
        key |= uint256(3) << 160;
        assertEq(gs.exists(key), false); // should be cleared
        key = uint256(uint160(address(erc1155)));
        key |= uint256(1) << 160;
        assertEq(gs.exists(key), false);
    }

    function test_BuyOther() public {
        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 180); // 90 seconds in, price @ 0.091
        uint256 seed = gs.seed();

        address charlie = address(0xcccc); // sanity check on using new 3rd party account
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.095 ether}(seed); // expect items: 2, 1, 2(6), 3

        // verify
        assertEq(gs.inventorySize(), 3);
        assertEq(gs.previous(), 3);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(charlie, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(7), charlie);
        assertEq(erc721.ownerOf(8), charlie);
        assertEq(erc1155.balanceOf(charlie, 1), 4000); // 4000 combined in bundle
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
    }

    function test_BuyPending() public {
        // setup
        gs.setAuction(2e16, 4e16, 3600);
        uint256 t0 = 1735675200; // 2024/12/31 8p utc
        vm.warp(t0 + 1800); // 30 minutes in, price @ 0.03
        uint256 seed = gs.seed();
        // emit log_uint(seed);

        // new inventory comes in during auction
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 4);

        assertEq(gs.inventorySize(), 9);
        assertEq(gs.previous(), 7);

        // buy
        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.095 ether}(seed); // expect items: 3, 5, 2, 3(6)

        // verify
        assertEq(gs.inventorySize(), 5);
        assertEq(gs.previous(), 5);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(charlie, 1), 4000); // 3
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
        assertEq(erc721.ownerOf(6), charlie); // 5
        assertEq(erc1155.balanceOf(charlie, 3), 42); // 2
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(8), charlie); // 3(6)

        (address tkn, uint256 id) = gs.inventory(0); // 0th, original
        assertEq(tkn, address(erc721));
        assertEq(id, 5);
        (tkn, id) = gs.inventory(1); // 1st, original
        assertEq(tkn, address(erc721));
        assertEq(id, 7);
        (tkn, id) = gs.inventory(2); // 5th slot backfill, included in shuffle
        assertEq(tkn, address(erc721));
        assertEq(id, 2);
        (tkn, id) = gs.inventory(4); // 8th slot backfill, from pending
        assertEq(tkn, address(erc721));
        assertEq(id, 4);
        (tkn, id) = gs.inventory(3); // 7th slot backfill, from pending
        assertEq(tkn, address(erc721));
        assertEq(id, 3);
    }

    function test_BuyLowPayment() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 885); // 15 seconds left, price @ 0.0115
        uint256 seed = gs.seed();

        vm.prank(alice);
        vm.expectRevert("insufficient payment");
        gs.buy{value: 0.011 ether}(seed);
    }

    function test_BuyLowInventory() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 885); // 15 seconds left, price @ 0.0115
        uint256 seed = gs.seed();

        vm.prank(alice);
        gs.buy{value: 0.012 ether}(seed);

        vm.warp(t0 + 930); // next auction
        seed = gs.seed();

        vm.prank(bob);
        vm.expectRevert("insufficient inventory");
        gs.buy{value: 0.1 ether}(seed);
    }

    function test_BuySame() public {
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3); // just padding some more inventory
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 4);
        gs.bump();

        uint256 t0 = 1702629000;
        vm.warp(t0 + 885); // 15 seconds left, price @ 0.0115
        uint256 seed = gs.seed();

        vm.prank(alice);
        gs.buy{value: 0.012 ether}(seed);

        vm.prank(bob);
        vm.expectRevert("already purchased");
        gs.buy{value: 0.012 ether}(seed);
    }

    function test_BuyInvalidSeed() public {
        uint256 t0 = 1702629000;
        vm.warp(t0);
        uint256 seed = gs.seed();

        vm.warp(t0 + 1350); // middle of next auction

        vm.prank(alice);
        vm.expectRevert("stale transaction");
        gs.buy{value: 0.06 ether}(seed);
    }
}