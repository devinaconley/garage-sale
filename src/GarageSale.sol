// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

contract GarageSale is
    Ownable,
    IERC721Receiver,
    IERC1155Receiver,
    ReentrancyGuard
{
    // events
    event Sell(
        address indexed seller,
        address indexed token,
        uint16 type_,
        uint256 id,
        uint256 amount
    );
    // TODO could trim down some these events
    event Buy(
        address indexed buyer,
        address[] tokens,
        uint16[] types,
        uint256[] ids,
        uint256[] amounts
    );
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
    struct Item {
        address token;
        uint96 id;
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
    Item[] public inventory; // TODO consider mapping
    mapping(uint256 => bool) public exists; // need this for ERC1155 only
    uint256 fees;

    /**
     * @notice initialize garage sale contract with reasonable defaults
     */
    constructor() Ownable(msg.sender) {
        offer = 1e12; // 0.000001 ether
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
     * @param from address of token sender
     * @param tokenId uint256 id of token
     */
    function onERC721Received(
        address /*operator*/,
        address from,
        uint256 tokenId,
        bytes calldata /*data*/
    ) external nonReentrant returns (bytes4) {
        require(tokens[msg.sender] == TokenType.ERC721, "unknown token");
        require(address(this).balance - fees > offer, "insufficient funds");

        inventory.push(Item(msg.sender, uint96(tokenId)));

        (bool sent, ) = payable(from).call{value: offer}("");
        require(sent, "ether transfer failed");

        emit Sell(from, msg.sender, uint16(TokenType.ERC721), tokenId, 1);
        return this.onERC721Received.selector;
    }

    /**
     * @notice handles receipt and purchase of an ERC1155 token
     * @param from address of token sender
     * @param id uint256 class id of token
     * @param value amount of token
     */
    function onERC1155Received(
        address /*operator*/,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata /*data*/
    ) external nonReentrant returns (bytes4) {
        require(tokens[msg.sender] == TokenType.ERC1155, "unknown token");
        require(address(this).balance - fees > offer, "insufficient funds");

        _receiveERC1155(from, msg.sender, id, value);

        (bool sent, ) = payable(from).call{value: offer}("");
        require(sent, "ether transfer failed");

        return this.onERC1155Received.selector;
    }

    /**
     * @notice handles receipt and purchase of an ERC1155 token batch
     * @param from address of token sender
     * @param ids array of token class ids
     * @param values array of token amounts (order and length must match ids array)
     */
    function onERC1155BatchReceived(
        address /*operator*/,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata /*data*/
    ) external nonReentrant returns (bytes4) {
        require(tokens[msg.sender] == TokenType.ERC1155, "unknown token");
        require(
            address(this).balance - fees > ids.length * offer,
            "insufficient funds"
        );
        require(
            ids.length == values.length,
            "inconsistent id and value arrays"
        );

        for (uint256 i; i < ids.length; i++) {
            _receiveERC1155(from, msg.sender, ids[i], values[i]);
        }

        (bool sent, ) = payable(from).call{value: ids.length * offer}("");
        require(sent, "ether transfer failed");

        return this.onERC1155BatchReceived.selector;
    }

    function _receiveERC1155(
        address from,
        address token,
        uint256 id,
        uint256 value
    ) private {
        // add item to inventory only if it doesn't already exist
        uint256 key = uint256(uint160(token));
        key |= uint256(id) << 160;
        if (!exists[key]) {
            inventory.push(Item(token, uint96(id)));
            exists[key] = true;
        }
        // emit
        emit Sell(from, token, uint16(TokenType.ERC1155), id, value);
    }

    // --- buy ----------------------------------------------------------------

    function buy() external payable {
        // TODO
    }

    function preview() external view returns (Item[] memory) {
        // TODO
    }

    function current() public view returns (uint256[] memory) {
        // TODO
    }

    function seed() public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(duration * ((block.timestamp) / duration))
            );
    }

    // --- info ---------------------------------------------------------------

    function inventorySize() external view returns (uint256) {
        return inventory.length;
    }

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
        bytes4 interface_ = type_ == uint16(TokenType.ERC721)
            ? type(IERC721).interfaceId
            : type(IERC1155).interfaceId;
        require(
            IERC165(token).supportsInterface(interface_),
            "token does not support expected interface"
        );
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
