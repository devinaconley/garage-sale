// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GarageSale} from "../src/GarageSale.sol";
import {TestERC721} from "../src/test/ERC721.sol";
import {TestERC1155} from "../src/test/ERC1155.sol";

contract ConfigurationTest is Test {
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
        gs.setOffer(5e15);
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

    function test_AuctionConfigMinLow() public {
        vm.expectRevert("min too low");
        gs.setAuction(5e11, 2e17, 900);
    }

    function test_AuctionConfigMinMaxInvalid() public {
        vm.expectRevert("min is greater than max price");
        gs.setAuction(2e16, 1e16, 900);
    }

    function test_AuctionConfigDurationLow() public {
        vm.expectRevert("duration too low");
        gs.setAuction(2e16, 4e16, 59);
    }

    function test_AuctionUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setAuction(5e14, 2e17, 1800);
    }

    function test_BundleSize() public {
        vm.expectEmit(address(gs));
        emit GarageSale.BundleUpdated(8);
        gs.setBundle(8);
        assertEq(gs.bundle(), 8);
    }

    function test_BundleSizeZero() public {
        vm.expectRevert("bundle size is zero");
        gs.setBundle(0);
    }

    function test_BundleSizeUnauthorized() public {
        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setBundle(8);
    }

    function test_TokenWhitelist() public {
        address tkn = address(erc721);
        address[] memory tokens = new address[](1);
        tokens[0] = tkn;
        uint16[] memory types = new uint16[](1);
        types[0] = 1;

        vm.expectEmit(address(gs));
        emit GarageSale.TokenUpdated(tkn, 1);
        gs.setTokens(tokens, types);
        assertEq(uint16(gs.tokens(tkn)), uint16(GarageSale.TokenType.ERC721));
    }

    function test_TokenWhitelist1155() public {
        address tkn = address(erc1155);
        address[] memory tokens = new address[](1);
        tokens[0] = tkn;
        uint16[] memory types = new uint16[](1);
        types[0] = 2;

        vm.expectEmit(address(gs));
        emit GarageSale.TokenUpdated(tkn, 2);
        gs.setTokens(tokens, types);
        assertEq(uint16(gs.tokens(tkn)), uint16(GarageSale.TokenType.ERC1155));
    }

    function test_TokenWhitelistBatch() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(erc721);
        tokens[1] = address(erc1155);
        uint16[] memory types = new uint16[](2);
        types[0] = 1;
        types[1] = 2;

        vm.expectEmit(address(gs));
        emit GarageSale.TokenUpdated(address(erc721), 1);
        emit GarageSale.TokenUpdated(address(erc1155), 2);

        gs.setTokens(tokens, types);

        assertEq(
            uint16(gs.tokens(address(erc721))),
            uint16(GarageSale.TokenType.ERC721)
        );
        assertEq(
            uint16(gs.tokens(address(erc1155))),
            uint16(GarageSale.TokenType.ERC1155)
        );
    }

    function test_TokenUnauthorized() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc721);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;

        vm.expectRevert("sender is not controller");
        vm.prank(alice);
        gs.setTokens(tokens, types);
    }

    function test_TokenTypeInvalid() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(0xabcde);
        uint16[] memory types = new uint16[](1);
        types[0] = 3;

        vm.expectRevert("token type is invalid");
        gs.setTokens(tokens, types);
    }

    function test_TokenZero() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;

        vm.expectRevert("token is zero address");
        gs.setTokens(tokens, types);
    }

    function test_TokenTypeWrong() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;

        vm.expectRevert("token does not support erc721 interface");
        gs.setTokens(tokens, types);
    }

    function test_TokenNotContract() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](1);
        types[0] = 1;

        vm.expectRevert();
        gs.setTokens(tokens, types);
    }

    function test_TokenMismatchLength() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(erc1155);
        uint16[] memory types = new uint16[](2);
        types[0] = 1;
        types[0] = 2;

        vm.expectRevert("arrays not equal length");
        gs.setTokens(tokens, types);
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
