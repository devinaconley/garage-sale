// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";

import {GarageSale} from "../src/GarageSale.sol";
import {TestERC721} from "../src/test/ERC721.sol";

contract ConfigurationTest is Test {
    GarageSale gs;
    TestERC721 erc721;
    address alice;
    address bob;

    function setUp() public {
        gs = new GarageSale();
        erc721 = new TestERC721("TestERC721", "NFT");
        alice = address(0xa11ce);
        bob = address(0x808);
        erc721.mint(alice, 5);
    }

    function test_Sell() public {
        // setup
        vm.deal(address(gs), 1e18); // fund contract
        gs.setToken(address(erc721), 1);

        vm.expectEmit(address(gs));
        emit GarageSale.Sell(alice, address(erc721), 1, 3, 1);

        // sell
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        // verify
        assertEq(address(gs).balance, 1e18 - 1e14); // 0.9999
        assertEq(erc721.balanceOf(alice), 4);
        assertEq(erc721.ownerOf(3), address(gs));
        (address tkn, uint96 id) = gs.inventory(0);
        assertEq(tkn, address(erc721));
        assertEq(id, 3);
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
    }

    function test_SellUnfunded() public {
        // setup
        gs.setToken(address(erc721), 1);

        // try sell
        vm.expectRevert("insufficient funds");
        vm.prank(alice);
        erc721.safeTransferFrom(alice, address(gs), 3);

        // verify no sell effects
        assertEq(address(gs).balance, 0);
        assertEq(erc721.balanceOf(alice), 5);
        assertEq(erc721.ownerOf(3), alice);
    }
}
