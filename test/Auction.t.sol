// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
        gs = new GarageSale(address(this));
        erc721 = new TestERC721("TestERC721", "NFT");
        erc1155 = new TestERC1155();
        alice = address(0xa11ce);
        bob = address(0x808);

        vm.deal(address(gs), 1e18);
        vm.deal(alice, 1e18);
        vm.deal(bob, 1e18);

        address[] memory tokens = new address[](2);
        tokens[0] = address(erc721);
        tokens[1] = address(erc1155);
        uint16[] memory types = new uint16[](2);
        types[0] = 1;
        types[1] = 2;
        gs.setTokens(tokens, types);

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
        uint256 prev = gs.available();
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
        uint256 prev = gs.available();
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
        uint256 prev = gs.available();

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

        // expect event
        address[] memory tokens = new address[](4);
        tokens[0] = address(erc1155);
        tokens[1] = address(erc721);
        tokens[2] = address(erc721);
        tokens[3] = address(erc1155);
        uint16[] memory types = new uint16[](4);
        types[0] = 2;
        types[1] = 1;
        types[2] = 1;
        types[3] = 2;
        uint256[] memory ids = new uint256[](4);
        ids[0] = 3;
        ids[1] = 7;
        ids[2] = 8;
        ids[3] = 1;
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 42;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 4000;
        vm.expectEmit(address(gs));
        emit GarageSale.Buy(alice, tokens, types, ids, amounts);

        // buy
        vm.prank(alice);
        gs.buy{value: 0.082 ether}(seed); // expect items: 2, 1, 2(6), 3

        // verify
        assertEq(gs.inventorySize(), 3);
        assertEq(gs.available(), 3);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(alice, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(7), alice);
        assertEq(erc721.ownerOf(8), alice);
        assertEq(erc1155.balanceOf(alice, 1), 6000); // 2000 already held + 4000 combined in bundle
        assertEq(erc1155.balanceOf(address(gs), 1), 0);

        (address tkn, uint96 id, ) = gs.inventory(0); // 0th
        assertEq(tkn, address(erc721));
        assertEq(id, 5);
        (tkn, id, ) = gs.inventory(1); // 6th backfill
        assertEq(tkn, address(erc721));
        assertEq(id, 6);
        (tkn, id, ) = gs.inventory(2); // 5th backfill
        assertEq(tkn, address(erc721));
        assertEq(id, 2);

        bytes32 key = keccak256(abi.encodePacked(address(erc1155), uint256(3)));
        assertEq(gs.exists(key), false); // should be cleared
        key = keccak256(abi.encodePacked(address(erc1155), uint256(1)));
        assertEq(gs.exists(key), false);
    }

    function test_BuyOther() public {
        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 90); // 90 seconds in, price @ 0.091
        uint256 seed = gs.seed();

        address charlie = address(0xcccc); // sanity check on using new 3rd party account
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.095 ether}(seed); // expect items: 2, 1, 2(6), 3

        // verify
        assertEq(gs.inventorySize(), 3);
        assertEq(gs.available(), 3);
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
        assertEq(gs.available(), 7);

        // buy
        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.095 ether}(seed); // expect items: 3, 5, 2, 3(6)

        // verify
        assertEq(gs.inventorySize(), 5);
        assertEq(gs.available(), 5);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(charlie, 1), 4000); // 3
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
        assertEq(erc721.ownerOf(6), charlie); // 5
        assertEq(erc1155.balanceOf(charlie, 3), 42); // 2
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(8), charlie); // 3(6)

        (address tkn, uint96 id, ) = gs.inventory(0); // 0th, original
        assertEq(tkn, address(erc721));
        assertEq(id, 5);
        (tkn, id, ) = gs.inventory(1); // 1st, original
        assertEq(tkn, address(erc721));
        assertEq(id, 7);
        (tkn, id, ) = gs.inventory(2); // 5th slot backfill, included in shuffle
        assertEq(tkn, address(erc721));
        assertEq(id, 2);
        (tkn, id, ) = gs.inventory(4); // 8th slot backfill, from pending
        assertEq(tkn, address(erc721));
        assertEq(id, 4);
        (tkn, id, ) = gs.inventory(3); // 7th slot backfill, from pending
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

    function test_BuyAutoBump() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 885); // 15 seconds left, price @ 0.0115
        uint256 seed = gs.seed();

        vm.prank(alice);
        gs.buy{value: 0.012 ether}(seed);

        vm.warp(t0 + 1350); // next auction
        seed = gs.seed();
        //emit log_uint(seed);

        // unable to preview or buy
        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        vm.expectRevert("insufficient inventory");
        gs.preview();
        vm.expectRevert("insufficient inventory");
        gs.buy{value: 0.1 ether}(seed);

        // new inventory comes in, but controller has not called bump()
        // second lot: 721:5, 721:6, 721:2, 1155:2(1), 721:4
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 2, 1, "");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 4);
        assertEq(gs.available(), 3);
        assertEq(gs.inventorySize(), 5);

        // should be able to buy
        vm.prank(charlie);
        gs.buy{value: 0.055 ether}(seed); // expect: 2, 1, 0, 1(3) of second lot

        // verify
        assertEq(gs.inventorySize(), 1);
        assertEq(gs.available(), 1);
        assertEq(gs.nonce(), t0 + 900);

        assertEq(erc721.ownerOf(2), charlie);
        assertEq(erc721.ownerOf(6), charlie);
        assertEq(erc721.ownerOf(5), charlie);
        assertEq(erc1155.balanceOf(charlie, 2), 1);
        assertEq(erc1155.balanceOf(address(gs), 2), 0);
        assertEq(erc721.balanceOf(charlie), 3);

        (address tkn, uint96 id, ) = gs.inventory(0); // only item remaining
        assertEq(tkn, address(erc721));
        assertEq(id, 4);
        assertEq(erc721.balanceOf(address(gs)), 1);
    }

    function test_Preview() public {
        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 180); // 3 minutes into auction window
        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();

        // expect items: 2, 1, 2(6), 3
        assertEq(tokens.length, 4);
        assertEq(tokens[0], address(erc1155));
        assertEq(tokens[1], address(erc721));
        assertEq(tokens[2], address(erc721));
        assertEq(tokens[3], address(erc1155));

        assertEq(types.length, 4);
        assertEq(types[0], 2);
        assertEq(types[1], 1);
        assertEq(types[2], 1);
        assertEq(types[3], 2);

        assertEq(ids.length, 4);
        assertEq(ids[0], 3);
        assertEq(ids[1], 7);
        assertEq(ids[2], 8);
        assertEq(ids[3], 1);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 42);
        assertEq(amounts[1], 1);
        assertEq(amounts[2], 1);
        assertEq(amounts[3], 4000);
    }

    function test_PreviewAfterBuy() public {
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3); // just padding some more inventory
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 4);
        gs.bump();

        uint256 t0 = 1702629000;
        vm.warp(t0 + 180); // 3 minutes into auction window
        uint256 seed = gs.seed();
        vm.prank(alice);
        gs.buy{value: 0.09 ether}(seed);

        // preview
        vm.expectRevert("already purchased");
        gs.preview();
    }

    function test_PreviewLowInventory() public {
        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 180); // 3 minutes into auction window
        uint256 seed = gs.seed();
        vm.prank(alice);
        gs.buy{value: 0.09 ether}(seed);

        vm.warp(t0 + 930); // next auction
        seed = gs.seed();

        vm.prank(bob);
        vm.expectRevert("insufficient inventory");
        gs.preview();
    }

    function test_PreviewAutoBump() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 180);
        uint256 seed = gs.seed();
        vm.prank(alice);
        gs.buy{value: 0.09 ether}(seed);

        vm.warp(t0 + 930); // next auction
        seed = gs.seed();

        vm.prank(bob);
        vm.expectRevert("insufficient inventory");
        gs.preview();

        // new inventory comes in, but controller has not called bump()
        // second lot: 721:5, 721:6, 721:2, 1155:2(1), 721:4
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 2, 1, "");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 4);
        assertEq(gs.available(), 3);
        assertEq(gs.inventorySize(), 5);

        // expect: 2, 1, 0, 1(3) of second lot
        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();

        assertEq(tokens.length, 4);
        assertEq(tokens[0], address(erc721));
        assertEq(tokens[1], address(erc721));
        assertEq(tokens[2], address(erc721));
        assertEq(tokens[3], address(erc1155));

        assertEq(types.length, 4);
        assertEq(types[0], 1);
        assertEq(types[1], 1);
        assertEq(types[2], 1);
        assertEq(types[3], 2);

        assertEq(ids.length, 4);
        assertEq(ids[0], 2);
        assertEq(ids[1], 6);
        assertEq(ids[2], 5);
        assertEq(ids[3], 2);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 1);
        assertEq(amounts[1], 1);
        assertEq(amounts[2], 1);
        assertEq(amounts[3], 1);
    }

    function testFuzz_Preview(uint256 x) public {
        vm.assume(x > 1701388800);
        vm.assume(x < 2553465600);
        vm.warp(x);

        // preview auction
        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();
        uint256 seed = gs.seed();

        // buy
        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.1 ether}(seed);

        // verify expected items
        for (uint256 i; i < gs.bundle(); i++) {
            if (types[i] == 1) {
                assertEq(tokens[i], address(erc721));
                assertEq(erc721.ownerOf(ids[i]), charlie);
                assertEq(amounts[i], 1);
            } else if (types[i] == 2) {
                assertEq(tokens[i], address(erc1155));
                assertEq(erc1155.balanceOf(charlie, ids[i]), amounts[i]);
            } else {
                assertTrue(false, "invalid type");
            }
        }
    }

    function test_Withdraw() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 450); // halfway through auction
        uint256 seed = gs.seed();
        vm.prank(alice);
        gs.buy{value: 0.055 ether}(seed);

        // eoa to receive eth
        gs.transferOwnership(bob);
        vm.prank(bob);
        gs.acceptOwnership(); // 2 step
        uint256 ownerPrev = bob.balance;
        uint256 contractPrev = address(gs).balance;

        vm.expectEmit(address(gs));
        emit GarageSale.Withdrawn(0.123 ether);
        vm.prank(bob);
        gs.withdraw(0.123 ether);

        assertEq(bob.balance - ownerPrev, 0.123 ether);
        assertEq(contractPrev - address(gs).balance, 0.123 ether);
    }

    function test_WithdrawContract() public {
        uint256 t0 = 1702629000;
        vm.warp(t0 + 450); // halfway through auction
        uint256 seed = gs.seed();
        vm.prank(alice);
        gs.buy{value: 0.055 ether}(seed);

        address owner = gs.owner();
        uint32 size;
        assembly {
            size := extcodesize(owner)
        }
        assertGt(size, 0); // expect transfer revert with contract owner

        vm.expectRevert("ether withdraw failed");
        gs.withdraw(0.123 ether);
    }

    function test_WithdrawZero() public {
        vm.expectRevert("withdraw amount is zero");
        gs.withdraw(0);
    }

    function test_WithdrawInsufficient() public {
        vm.expectRevert("insufficient balance");
        gs.withdraw(2.34 ether);
    }

    function test_WithdrawUnauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        vm.prank(alice);
        gs.withdraw(0.5 ether);
    }

    function test_BuyLargeBundle() public {
        // setup
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 2, 1, "");
        erc721.mint(alice, 5);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 10);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 11);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 12);
        // inventory: [erc721:5, erc721:7, erc1155:3(42), erc1155:1(4000), erc721:2, erc721:6, erc721:8, erc1155:2(1), erc721:10, erc721:11, erc721:12]

        gs.bump();
        gs.setBundle(8); // bundle now 8 items

        assertEq(gs.inventorySize(), 11);
        assertEq(gs.available(), 11);
        assertEq(gs.bundle(), 8);

        uint256 t0 = 1702629000; // 830a utc
        vm.warp(t0 + 300); // 5 minutes in, price @ 0.07
        uint256 seed = gs.seed();

        address charlie = address(0xcccc); // sanity check on using new 3rd party account
        vm.deal(charlie, 1e18);
        vm.prank(charlie);
        gs.buy{value: 0.07 ether}(seed); // expect items: 1, 7, 3, 3(8), 1(10), 3(7(9)), 2, 3(5)

        // verify
        assertEq(gs.inventorySize(), 3);
        assertEq(gs.available(), 3);
        assertEq(gs.nonce(), t0);

        assertEq(erc721.ownerOf(7), charlie);
        assertEq(erc1155.balanceOf(charlie, 2), 1);
        assertEq(erc1155.balanceOf(address(gs), 2), 0);
        assertEq(erc1155.balanceOf(charlie, 1), 4000);
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
        assertEq(erc721.ownerOf(10), charlie);
        assertEq(erc721.ownerOf(12), charlie);
        assertEq(erc721.ownerOf(11), charlie);
        assertEq(erc1155.balanceOf(charlie, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
        assertEq(erc721.ownerOf(6), charlie);
    }

    function test_PreviewLargeBundle() public {
        // setup
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 2, 1, "");
        erc721.mint(alice, 5);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 10);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 11);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 12);
        // inventory: [erc721:5, erc721:7, erc1155:3(42), erc1155:1(4000), erc721:2, erc721:6, erc721:8, erc1155:2(1), erc721:10, erc721:11, erc721:12]

        gs.bump();
        gs.setBundle(8); // bundle now 8 items

        uint256 t0 = 1702629000;
        vm.warp(t0 + 300); // 5 minutes into auction window

        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();

        // expect items: 1, 7, 3, 3(8), 1(10), 3(7(9)), 2, 3(5)
        assertEq(tokens.length, 8);
        assertEq(tokens[0], address(erc721));
        assertEq(tokens[1], address(erc1155));
        assertEq(tokens[2], address(erc1155));
        assertEq(tokens[3], address(erc721));
        assertEq(tokens[4], address(erc721));
        assertEq(tokens[5], address(erc721));
        assertEq(tokens[6], address(erc1155));
        assertEq(tokens[7], address(erc721));

        assertEq(types.length, 8);
        assertEq(types[0], 1);
        assertEq(types[1], 2);
        assertEq(types[2], 2);
        assertEq(types[3], 1);
        assertEq(types[4], 1);
        assertEq(types[5], 1);
        assertEq(types[6], 2);
        assertEq(types[7], 1);

        assertEq(ids.length, 8);
        assertEq(ids[0], 7);
        assertEq(ids[1], 2);
        assertEq(ids[2], 1);
        assertEq(ids[3], 10);
        assertEq(ids[4], 12);
        assertEq(ids[5], 11);
        assertEq(ids[6], 3);
        assertEq(ids[7], 6);

        assertEq(amounts.length, 8);
        assertEq(amounts[0], 1);
        assertEq(amounts[1], 1);
        assertEq(amounts[2], 4000);
        assertEq(amounts[3], 1);
        assertEq(amounts[4], 1);
        assertEq(amounts[5], 1);
        assertEq(amounts[6], 42);
        assertEq(amounts[7], 1);
    }

    function test_BuyBad() public {
        TestERC721 bad = new TestERC721("BadERC721", "BAD");

        address[] memory tokens = new address[](1);
        tokens[0] = address(bad);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;
        gs.setTokens(tokens, types);

        bad.mint(alice, 3);
        vm.prank(alice);
        bad.safeTransferFrom(alice, address(gs), 1);
        vm.prank(alice);
        bad.safeTransferFrom(alice, address(gs), 2);
        gs.bump();

        types[0] = 0;
        gs.setTokens(tokens, types); // later remove misbehaving token
        // (but items already in inventory)
        // inventory: [..., bad:1, bad:2]

        uint256 t0 = 1767096000;
        vm.warp(t0 + 810); // 810 seconds in, price @ 0.019
        uint256 seed = gs.seed();
        // emit log_uint(seed);

        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);

        // expect event
        tokens = new address[](4);
        tokens[0] = address(bad);
        tokens[1] = address(erc721);
        tokens[2] = address(bad);
        tokens[3] = address(erc1155);
        types = new uint16[](4);
        types[0] = 0; // unknown
        types[1] = 1;
        types[2] = 0; // unknown
        types[3] = 2;
        uint256[] memory ids = new uint256[](4);
        ids[0] = 2;
        ids[1] = 2;
        ids[2] = 1;
        ids[3] = 3;
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 0; // indicate bad
        amounts[1] = 1;
        amounts[2] = 0; // indicate bad
        amounts[3] = 42;
        vm.expectEmit(address(gs));
        emit GarageSale.Buy(charlie, tokens, types, ids, amounts);

        // buy
        vm.prank(charlie);
        gs.buy{value: 0.02 ether}(seed); // expect items: 8, 4, 4(7), 2

        // verify
        assertEq(gs.inventorySize(), 5); // should still remove bad item from inventory
        assertEq(gs.available(), 5);
        assertEq(gs.nonce(), t0);

        assertEq(bad.ownerOf(2), address(gs)); // leave stranded in contract
        assertEq(erc721.ownerOf(2), charlie);
        assertEq(bad.ownerOf(1), address(gs)); // leave stranded in contract
        assertEq(erc1155.balanceOf(charlie, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
    }

    function test_PreviewBad() public {
        TestERC721 bad = new TestERC721("BadERC721", "BAD");

        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(bad);
        uint16[] memory types_ = new uint16[](1);
        types_[0] = 1;
        gs.setTokens(tokens_, types_);

        bad.mint(alice, 3);
        vm.prank(alice);
        bad.safeTransferFrom(alice, address(gs), 1);
        vm.prank(alice);
        bad.safeTransferFrom(alice, address(gs), 2);
        gs.bump();

        types_[0] = 0;
        gs.setTokens(tokens_, types_); // later remove misbehaving token
        // (but items already in inventory)
        // inventory: [..., bad:1, bad:2]

        uint256 t0 = 1767096000;
        vm.warp(t0 + 450);

        // expect: 8, 4, 4(7), 2
        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();

        assertEq(tokens.length, 4);
        assertEq(tokens[0], address(bad));
        assertEq(tokens[1], address(erc721));
        assertEq(tokens[2], address(bad));
        assertEq(tokens[3], address(erc1155));

        assertEq(types.length, 4);
        assertEq(types[0], 0); // unknown
        assertEq(types[1], 1);
        assertEq(types[2], 0); // unknown
        assertEq(types[3], 2);

        assertEq(ids.length, 4);
        assertEq(ids[0], 2);
        assertEq(ids[1], 2);
        assertEq(ids[2], 1);
        assertEq(ids[3], 3);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0); // bad
        assertEq(amounts[1], 1);
        assertEq(amounts[2], 0); // bad
        assertEq(amounts[3], 42);
    }

    function test_BuyBig() public {
        erc1155.mint(alice, 1e30 + 5, 1000);
        erc1155.mint(alice, 1e48 + 123, 500);
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1e30 + 5, 1000, "");
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1e48 + 123, 500, "");
        gs.bump();
        // inventory: [..., erc1155:1e30+5:1000, erc1155:1e48+123:500]

        uint256 t0 = 1767096000;
        vm.warp(t0 + 810); // 810 seconds in, price @ 0.019
        uint256 seed = gs.seed();

        address charlie = address(0xcccc);
        vm.deal(charlie, 1e18);

        // expect event
        address[] memory tokens = new address[](4);
        tokens[0] = address(erc1155);
        tokens[1] = address(erc721);
        tokens[2] = address(erc1155);
        tokens[3] = address(erc1155);
        uint16[] memory types = new uint16[](4);
        types[0] = 2;
        types[1] = 1;
        types[2] = 2;
        types[3] = 2;
        uint256[] memory ids = new uint256[](4);
        ids[0] = 1e48 + 123; // id256
        ids[1] = 2;
        ids[2] = 1e30 + 5; // id256
        ids[3] = 3;
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 500;
        amounts[1] = 1;
        amounts[2] = 1000;
        amounts[3] = 42;
        vm.expectEmit(address(gs));
        emit GarageSale.Buy(charlie, tokens, types, ids, amounts);

        // buy
        vm.prank(charlie);
        gs.buy{value: 0.02 ether}(seed); // expect items: 8, 4, 4(7), 2

        // verify
        assertEq(gs.inventorySize(), 5);
        assertEq(gs.available(), 5);
        assertEq(gs.nonce(), t0);

        assertEq(erc1155.balanceOf(charlie, 1e48 + 123), 500);
        assertEq(erc1155.balanceOf(address(gs), 1e48 + 123), 0);
        assertEq(erc721.ownerOf(2), charlie);
        assertEq(erc1155.balanceOf(charlie, 1e30 + 5), 1000);
        assertEq(erc1155.balanceOf(address(gs), 1e30 + 5), 0);
        assertEq(erc1155.balanceOf(charlie, 3), 42);
        assertEq(erc1155.balanceOf(address(gs), 3), 0);
    }

    function test_PreviewBig() public {
        erc1155.mint(alice, 1e30 + 5, 1000);
        erc1155.mint(alice, 1e48 + 123, 500);
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1e30 + 5, 1000, "");
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1e48 + 123, 500, "");
        gs.bump();
        // inventory: [..., erc1155:1e30+5:1000, erc1155:1e48+123:500]

        uint256 t0 = 1767096000;
        vm.warp(t0 + 450);
        // emit log_uint(gs.seed());

        // expect: 8, 4, 4(7), 2
        (
            address[] memory tokens,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        ) = gs.preview();

        assertEq(tokens.length, 4);
        assertEq(tokens[0], address(erc1155));
        assertEq(tokens[1], address(erc721));
        assertEq(tokens[2], address(erc1155));
        assertEq(tokens[3], address(erc1155));

        assertEq(types.length, 4);
        assertEq(types[0], 2);
        assertEq(types[1], 1);
        assertEq(types[2], 2);
        assertEq(types[3], 2);

        assertEq(ids.length, 4);
        assertEq(ids[0], 1e48 + 123); // id256
        assertEq(ids[1], 2);
        assertEq(ids[2], 1e30 + 5); // id256
        assertEq(ids[3], 3);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 500);
        assertEq(amounts[1], 1);
        assertEq(amounts[2], 1000);
        assertEq(amounts[3], 42);
    }
}
