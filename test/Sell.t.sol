// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {GarageSale} from "../src/GarageSale.sol";
import {TestERC721} from "../src/test/ERC721.sol";
import {TestERC1155} from "../src/test/ERC1155.sol";
import {BulkSend} from "../src/test/BulkSend.sol";

contract SellTest is Test {
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
        erc721.mint(alice, 5);
        erc721.mint(bob, 2);
        erc1155.mint(alice, 1, 5000);
        erc1155.mint(alice, 2, 1);
        erc1155.mint(alice, 3, 42);
        erc1155.mint(bob, 1, 3000);
    }

    function test_Sell() public {
        // setup
        vm.deal(address(gs), 1e18); // fund contract
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;
        gs.setTokens(tokens, types);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 3, 1);

        // sell
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        // verify
        assertEq(address(gs).balance, 1e18 - 1e12); // 0.999999
        assertEq(erc721.balanceOf(alice), 4);
        assertEq(erc721.ownerOf(3), address(gs));
        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc721));
        assertEq(id, 3);
        assertEq(gs.inventorySize(), 1);
    }

    function test_SellAgain() public {
        // setup
        vm.deal(address(gs), 1e18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;
        gs.setTokens(tokens, types);

        // sell multiple
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 3, 1);
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(bob, address(erc721), 1, 6, 1);
        vm.prank(bob);
        erc721.safeTransferFrom(bob, address(gs), 6);

        // verify
        assertEq(address(gs).balance, 1e18 - 2e12); // 0.999998
        assertEq(erc721.balanceOf(alice), 4);
        assertEq(erc721.balanceOf(bob), 1);
        assertEq(erc721.ownerOf(3), address(gs));
        assertEq(erc721.ownerOf(6), address(gs));
        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc721));
        assertEq(id, 3);
        (tkn, id) = gs.inventory(1);
        assertEq(tkn, address(erc721));
        assertEq(id, 6);
        assertEq(gs.inventorySize(), 2);
    }

    function test_SellUnknown() public {
        // setup
        vm.deal(address(gs), 1e18);

        // try sell
        vm.expectRevert("unknown token");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        // verify no sell effects
        assertEq(address(gs).balance, 1e18);
        assertEq(erc721.balanceOf(alice), 5);
        assertEq(erc721.ownerOf(3), alice);
        assertEq(gs.inventorySize(), 0);
    }

    function test_SellUnfunded() public {
        // setup
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;
        gs.setTokens(tokens, types);

        // try sell
        vm.expectRevert("insufficient funds");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        // verify no sell effects
        assertEq(address(gs).balance, 0);
        assertEq(erc721.balanceOf(alice), 5);
        assertEq(erc721.ownerOf(3), alice);
    }

    function test_SellErc1155() public {
        // setup
        vm.deal(address(gs), 1e18); // fund contract
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 2;
        gs.setTokens(tokens, types);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 1, 1000);

        // sell
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1, 1000, "");

        // verify
        assertEq(address(gs).balance, 1e18 - 1e12); // 0.999999
        assertEq(erc1155.balanceOf(alice, 1), 4000);
        assertEq(erc1155.balanceOf(address(gs), 1), 1000);
        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc1155));
        assertEq(id, 1);
        uint256 key = uint256(uint160(address(erc1155)));
        key |= uint256(1) << 160;
        assertEq(gs.exists(key), true);
        assertEq(gs.inventorySize(), 1);
    }

    function test_SellErc1155Again() public {
        // setup
        vm.deal(address(gs), 1e18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 2;
        gs.setTokens(tokens, types);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 1, 1000);

        // sell
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1, 1000, "");

        // verify
        assertEq(address(gs).balance, 1e18 - 1e12); // 0.999999
        assertEq(erc1155.balanceOf(alice, 1), 4000);
        assertEq(erc1155.balanceOf(address(gs), 1), 1000);
        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc1155));
        vm.expectRevert();
        (tkn, id) = gs.inventory(1); // should not create new item
        uint256 key = uint256(uint160(address(erc1155)));
        key |= uint256(1) << 160;
        assertEq(gs.exists(key), true);
        assertEq(gs.inventorySize(), 1);
    }

    function test_SellErc1155Unknown() public {
        // setup
        vm.deal(address(gs), 1e18);

        // try sell
        vm.expectRevert("unknown token");
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1, 1000, "");

        // verify no sell effects
        assertEq(address(gs).balance, 1e18);
        assertEq(erc1155.balanceOf(alice, 1), 5000);
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
        assertEq(gs.inventorySize(), 0);
    }

    function test_SellErc1155Unfunded() public {
        // setup
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 2;
        gs.setTokens(tokens, types);

        // try sell
        vm.expectRevert("insufficient funds");
        vm.prank(alice);
        erc1155.safeTransferFrom(alice, address(gs), 1, 1000, "");

        // verify no sell effects
        assertEq(address(gs).balance, 0);
        assertEq(erc1155.balanceOf(alice, 1), 5000);
        assertEq(erc1155.balanceOf(address(gs), 1), 0);
    }

    function test_SellErc1155Batch() public {
        // setup
        vm.deal(address(gs), 1e18);
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 2;
        gs.setTokens(tokens, types);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 1, 2500);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 2, 1);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 3, 42);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc1155), 2, 1, 2000);

        // sell
        vm.prank(alice);
        uint256[] memory ids = new uint256[](4);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 1;
        uint256[] memory values = new uint256[](4);
        values[0] = 2500;
        values[1] = 1;
        values[2] = 42;
        values[3] = 2000;
        erc1155.safeBatchTransferFrom(alice, address(gs), ids, values, "");

        // verify
        assertEq(address(gs).balance, 1e18 - 4e12); // 0.999996
        assertEq(erc1155.balanceOf(alice, 1), 500);
        assertEq(erc1155.balanceOf(alice, 2), 0);
        assertEq(erc1155.balanceOf(alice, 3), 0);
        assertEq(erc1155.balanceOf(address(gs), 1), 4500);
        assertEq(erc1155.balanceOf(address(gs), 2), 1);
        assertEq(erc1155.balanceOf(address(gs), 3), 42);
        assertEq(gs.inventorySize(), 3);
    }

    function test_SellMany() public {
        // setup
        vm.deal(address(gs), 1e18);
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc721);
        tokens[1] = address(erc1155);
        uint16[] memory types = new uint16[](2);
        types[0] = 1;
        types[1] = 2;
        gs.setTokens(tokens, types);

        // sell
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 5); // erc721 #5
        vm.prank(bob);
        erc721.safeTransferFrom(bob, address(gs), 7); // erc721 #7
        vm.prank(alice);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 3;
        ids[1] = 1;
        uint256[] memory values = new uint256[](2);
        values[0] = 42;
        values[1] = 3000;
        erc1155.safeBatchTransferFrom(alice, address(gs), ids, values, ""); // erc1155 #3: 42, #1: 3000
        vm.prank(bob);
        erc1155.safeTransferFrom(bob, address(gs), 1, 1000, ""); // erc115 #1: 1000 (item already exists)
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 2); // erc721 #2

        // verify
        assertEq(address(gs).balance, 1e18 - 6e12); // 0.999994
        assertEq(erc721.balanceOf(alice), 3); // 5 - 2
        assertEq(erc721.balanceOf(bob), 1); // 2 - 1
        assertEq(erc721.balanceOf(address(gs)), 3);

        assertEq(erc1155.balanceOf(alice, 1), 2000);
        assertEq(erc1155.balanceOf(alice, 2), 1);
        assertEq(erc1155.balanceOf(alice, 3), 0);

        assertEq(erc1155.balanceOf(address(gs), 1), 4000); // 3000 + 1000
        assertEq(erc1155.balanceOf(address(gs), 2), 0);
        assertEq(erc1155.balanceOf(address(gs), 3), 42);

        assertEq(gs.inventorySize(), 5);

        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc721));
        assertEq(id, 5);
        (tkn, id) = gs.inventory(1);
        assertEq(tkn, address(erc721));
        assertEq(id, 7);
        (tkn, id) = gs.inventory(2);
        assertEq(tkn, address(erc1155));
        assertEq(id, 3);
        (tkn, id) = gs.inventory(3);
        assertEq(tkn, address(erc1155));
        assertEq(id, 1);
        (tkn, id) = gs.inventory(4);
        assertEq(tkn, address(erc721));
        assertEq(id, 2);
    }

    function test_SellErc721Bulk() public {
        // setup
        vm.deal(address(gs), 1e18); // fund contract
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;
        gs.setTokens(tokens, types);
        BulkSend router = new BulkSend();
        vm.prank(alice);
        erc721.setApprovalForAll(address(router), true);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 1, 1);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 2, 1);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 3, 1);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 4, 1);
        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 5, 1);

        // sell bulk
        uint256[] memory ids = new uint256[](5);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 4;
        ids[4] = 5;
        vm.prank(alice);
        router.send(address(gs), address(erc721), ids);

        // verify
        assertEq(address(gs).balance, 1e18 - 5e12); // 0.999995
        assertEq(erc721.balanceOf(alice), 0);
        assertEq(erc721.balanceOf(address(gs)), 5);
        assertEq(erc721.ownerOf(3), address(gs));
        assertEq(gs.inventorySize(), 5);
    }
}
