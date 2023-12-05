// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract GarageSale is Ownable, IERC721Receiver, IERC1155Receiver {
    // events
    event Sell(address indexed seller, address indexed token, uint256 id);
    event Buy(address indexed buyer, address[] tokens, uint56[] ids);
    event OfferUpdated(uint256 offer);
    event AuctionUpdated(uint256 min, uint256 max, uint256 duration);
    event TakeUpdated(uint256 take);
    event TokenUpdated(address indexed token, uint16 type_);
    event ControllerUpdated(address controller);

    // types
    enum TokenType {
        Unknown,
        ERC721,
        ERC1155
    }

    // config
    uint256 public offer; // wei
    uint256 public min; // wei
    uint256 public max; // wei
    uint32 public duration; // seconds
    uint8 public bundle; // size
    uint16 public take; // fee (out of 1e3)
    address public controller;

    // data
    mapping(address => TokenType) public tokens;
    uint256 fees;

    /**
     * @notice initialize garage sale contract with reasonable defaults
     */
    constructor() Ownable(msg.sender) {
        offer = 1e14; // 0.0001 ether
        min = 1e15; // 0.001 ether
        max = 1e17; // 0.1 ether
        duration = 15 * 60; // 15 minutes
        bundle = 4;
        take = 1e2; // 10%
        controller = msg.sender;
    }

    modifier onlyController() {
        require(
            msg.sender == controller || msg.sender == owner(),
            "sender is not controller"
        );
        _;
    }

    /**
     * erc165 check for standard interface support
     * @param interfaceId interface id in question
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    // --- sell ---------------------------------------------------------------

    /**
     * @notice handles receipt and purchase of an ERC721 token
     * @param operator address of operator
     * @param from address of token sender
     * @param tokenId uint256 id of token
     * @param data other data
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {}

    /**
     * @notice handles receipt and purchase of an ERC1155 token
     * @param operator address of operator
     * @param from address of token sender
     * @param id uint256 class id of token
     * @param value amount of token
     * @param data other data
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {}

    /**
     * @notice handles receipt and purchase of an ERC1155 token batch
     * @param operator address of operator
     * @param from address of token sender
     * @param ids array of token class ids
     * @param values array of token amounts (order and length must match ids array)
     * @param data other data
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {}

    // --- configuration ------------------------------------------------------

    /**
     * @param offer_ new offer price (in wei) to sell a token to the protocol
     */
    function setOffer(uint256 offer_) public onlyController {
        require(offer_ > 0, "offer is zero");
        require(offer_ < min / bundle, "offer too high");
        offer = offer_;
        emit OfferUpdated(offer_);
    }

    /**
     * @notice update params for dutch auction resale
     * @param min_ new minimum price
     * @param max_ new maximum price
     * @param duration_ new auction duration
     */
    function setAuction(
        uint256 min_,
        uint256 max_,
        uint256 duration_
    ) public onlyController {
        require(min_ > bundle * offer, "min too low");
        require(min_ <= max_, "min is greater than max price");
        min = min_;
        max = max_;
        duration = uint32(duration_);
        emit AuctionUpdated(min_, max_, duration_);
    }

    /**
     * @param take_ new take rate
     */
    function setTake(uint256 take_) public onlyController {
        require(take < 1e3, "fee too high");
        take = uint16(take_);
        emit TakeUpdated(take_);
    }

    /**
     * @param token address of token to update
     * @param type_ new token type
     */
    function setToken(address token, uint16 type_) public onlyController {
        require(token != address(0), "token is zero address");
        require(type_ <= uint16(TokenType.ERC1155), "token type is invalid");
        // TODO verify token type
        tokens[token] = TokenType(type_);
        emit TokenUpdated(token, type_);
    }

    /**
     * @param controller_ new controller address
     */
    function setController(address controller_) public onlyOwner {
        controller = controller_;
        emit ControllerUpdated(controller_);
    }
}
