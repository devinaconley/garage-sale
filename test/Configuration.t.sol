// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GarageSale} from "../src/GarageSale.sol";

contract ConfigurationTest is Test {
    GarageSale gs;
    address alice;
    address bob;

    function setUp() public {
        gs = new GarageSale();
        alice = address(0xa11ce);
        bob = address(0x808);
    }

    function test_OfferPrice() public {
        vm.expectEmit(address(gs));
        emit GarageSale.OfferUpdated(1e14);
        gs.setOffer(1e14); // 0.0001
        assertEq(gs.offer(), 1e14);
    }

    function test_OfferPriceZero() public {
        vm.expectRevert("offer is zero");
        gs.setOffer(0);
    }

    function test_OfferPriceHigh() public {
        vm.expectRevert("offer too high");
        gs.setOffer(5e14);
    }

    function test_OfferPriceUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setOffer(1e13);
    }

    function testFuzz_OfferPrice(uint256 x) public {
        vm.assume(x > 0);
        vm.assume(x < 1e15 / 4);
        gs.setOffer(x);
        assertEq(gs.offer(), x);
    }

    function test_OfferPriceController() public {
        gs.setController(alice);
        vm.prank(alice);
        gs.setOffer(2e14); // 0.0002
        assertEq(gs.offer(), 2e14);
    }

    function test_OfferPriceOwner() public {
        gs.setController(alice);
        // call as owner
        gs.setOffer(1e13); // 0.00001
        assertEq(gs.offer(), 1e13);
    }

    function test_AuctionConfig() public {
        vm.expectEmit(address(gs));
        emit GarageSale.AuctionUpdated(5e14, 2e17, 1800);
        gs.setAuction(5e14, 2e17, 1800); // 0.2 -> 0.0005 over 30 min
        assertEq(gs.min(), 5e14);
        assertEq(gs.max(), 2e17);
        assertEq(gs.duration(), 1800);
    }

    function test_AuctionUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setAuction(5e14, 2e17, 1800);
    }

    function test_TakeRate() public {
        vm.expectEmit(address(gs));
        emit GarageSale.TakeUpdated(30);
        gs.setTake(30); // 3%
        assertEq(gs.take(), 3e1);
    }

    function test_TakeUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setTake(8);
    }

    function test_TokenWhitelist() public {
        address tkn = address(12345);
        vm.expectEmit(address(gs));
        emit GarageSale.TokenUpdated(tkn, 1);
        gs.setToken(tkn, 1);
        assertEq(uint16(gs.tokens(tkn)), uint16(GarageSale.TokenType.ERC721));
    }

    function test_TokenWhitelist1155() public {
        address tkn = address(1155);
        vm.expectEmit(address(gs));
        emit GarageSale.TokenUpdated(tkn, 2);
        gs.setToken(tkn, 2);
        assertEq(uint16(gs.tokens(tkn)), uint16(GarageSale.TokenType.ERC1155));
    }

    function test_TokenUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setToken(address(333), 1);
    }

    function test_TokenTypeInvalid() public {
        vm.expectRevert("token type is invalid");
        gs.setToken(address(0xabcde), 3);
    }

    function test_Controller() public {
        vm.expectEmit(address(gs));
        emit GarageSale.ControllerUpdated(bob);
        gs.setController(bob);
        assertEq(gs.controller(), bob);
    }

    function test_ControllerUnauthorized() public {
        gs.setController(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            ) // controller cannot change reassign their role
        );
        vm.prank(alice);
        gs.setController(bob);
        assertEq(gs.controller(), alice);
    }
}
