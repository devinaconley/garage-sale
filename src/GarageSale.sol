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
    event AuctionUpdated(uint96 min, uint96 max, uint32 duration);
    event TokenUpdated(address indexed token, uint16 type_);
    event ControllerUpdated(address controller);
    event Funded(uint256 amount);
    event Withdrawn(uint256 amount);

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
    uint96 public min; // wei
    uint96 public max; // wei
    uint32 public duration; // seconds
    uint8 public bundle; // size
    address public controller;

    // data
    mapping(address => TokenType) public tokens;
    Item[] public inventory;
    mapping(uint256 => bool) public exists; // need this for ERC1155 only
    uint256 public available; // last inventory size
    uint256 public nonce; // last auction window purchased

    /**
     * @notice initialize garage sale contract with reasonable defaults
     */
    constructor() Ownable(msg.sender) {
        offer = 1e12; // 0.000001 ether
        min = 1e16; // 0.01 ether
        max = 1e17; // 0.1 ether
        duration = 15 * 60; // 15 minutes
        bundle = 4;
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
        uint256 offer_ = offer;
        require(address(this).balance > offer_, "insufficient funds");

        inventory.push(Item(msg.sender, uint96(tokenId)));

        (bool sent, ) = payable(from).call{value: offer_}("");
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
        uint256 offer_ = offer;
        require(address(this).balance > offer_, "insufficient funds");

        _receiveERC1155(from, msg.sender, id, value);

        (bool sent, ) = payable(from).call{value: offer_}("");
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
        uint256 count = ids.length;
        uint256 offer_ = offer;
        require(address(this).balance > count * offer_, "insufficient funds");
        require(count == values.length, "inconsistent id and value arrays");

        for (uint256 i; i < count; i++) {
            _receiveERC1155(from, msg.sender, ids[i], values[i]);
        }

        (bool sent, ) = payable(from).call{value: count * offer_}("");
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

    function buy(uint256 seed_) external payable nonReentrant {
        require(msg.value >= price(), "insufficient payment");
        uint256 avail = available;
        uint256 bund = bundle;
        uint256 total = inventory.length;
        if (avail <= bund && total > bund) {
            avail = bund + 1; // we can auto bump
        }
        require(avail > bund, "insufficient inventory");
        uint256 t = start();
        require(t > nonce, "already purchased");
        uint256 s = _seed(t);
        require(seed_ == s, "stale transaction");

        address[] memory addrs = new address[](bund);
        uint16[] memory types = new uint16[](bund);
        uint256[] memory ids = new uint256[](bund);
        uint256[] memory amounts = new uint256[](bund);

        // shuffle
        for (uint256 i; i < bund; i++) {
            // get item data
            uint256 r = s % (avail - i);
            addrs[i] = inventory[r].token;
            ids[i] = inventory[r].id;
            // backfill removed item
            inventory[r] = inventory[avail - i - 1];
            if (total > avail) {
                // reindex new pending items
                inventory[avail - i - 1] = inventory[total - i - 1];
            }
            inventory.pop();
        }
        available = total - bund;
        nonce = t;

        // send all
        for (uint256 i; i < bund; i++) {
            TokenType type_ = tokens[addrs[i]];
            types[i] = uint16(type_);
            if (type_ == TokenType.ERC721) {
                amounts[i] = 1;
                IERC721(addrs[i]).safeTransferFrom(
                    address(this),
                    msg.sender,
                    ids[i]
                );
            } else {
                // get full balance
                IERC1155 tkn = IERC1155(addrs[i]);
                uint256 bal = tkn.balanceOf(address(this), ids[i]);
                amounts[i] = bal;
                // clear exists key
                uint256 key = uint256(uint160(addrs[i]));
                key |= uint256(ids[i]) << 160;
                exists[key] = false;
                // send all
                tkn.safeTransferFrom(
                    address(this),
                    msg.sender,
                    ids[i],
                    bal,
                    ""
                );
            }
        }
        emit Buy(msg.sender, addrs, types, ids, amounts);
    }

    function preview()
        external
        view
        returns (
            address[] memory tokens_,
            uint16[] memory types,
            uint256[] memory ids,
            uint256[] memory amounts
        )
    {
        uint256 avail = available;
        uint256 bund = bundle;
        if (avail <= bund && inventory.length > bund) {
            avail = bund + 1; // we can auto bump
        }
        require(avail > bund, "insufficient inventory");

        tokens_ = new address[](bund);
        types = new uint16[](bund);
        ids = new uint256[](bund);
        amounts = new uint256[](bund);

        // preview shuffle
        uint256[] memory rand = new uint256[](bund);
        uint256 s = seed();
        for (uint256 i; i < bund; i++) {
            uint256 r = s % (avail - i);
            rand[i] = r;
            for (uint256 j = i; j > 0; j--) {
                // walk back through replacements
                if (r == rand[j - 1]) {
                    r = avail - j;
                }
            }
            Item storage item = inventory[r];
            tokens_[i] = item.token;
            types[i] = uint16(tokens[item.token]);
            ids[i] = item.id;
            amounts[i] = tokens[item.token] == TokenType.ERC721
                ? 1
                : IERC1155(item.token).balanceOf(address(this), item.id);
        }
    }

    function price() public view returns (uint256) {
        uint256 m = max;
        uint256 d = duration;
        uint256 elapsed = block.timestamp % d;
        return m - ((m - min) * elapsed) / d;
    }

    function seed() public view returns (uint256) {
        return _seed(start());
    }

    function _seed(uint256 start_) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(start_, available)));
    }

    // --- info ---------------------------------------------------------------

    function inventorySize() external view returns (uint256) {
        return inventory.length;
    }

    function start() public view returns (uint256) {
        uint256 d = duration;
        return d * (block.timestamp / d);
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
        uint96 min_,
        uint96 max_,
        uint32 duration_
    ) external onlyController {
        require(min_ > bundle * offer, "min too low");
        require(min_ <= max_, "min is greater than max price");
        min = min_;
        max = max_;
        duration = uint32(duration_);
        emit AuctionUpdated(min_, max_, duration_);
    }

    /**
     * @param tokens_ addresses of tokens to update
     * @param types new token types
     */
    function setTokens(
        address[] calldata tokens_,
        uint16[] calldata types
    ) external onlyController {
        require(tokens_.length == types.length, "arrays not equal length");
        for (uint256 i; i < tokens_.length; i++) {
            require(tokens_[i] != address(0), "token is zero address");
            require(
                types[i] <= uint16(TokenType.ERC1155),
                "token type is invalid"
            );
            bytes4 interface_ = types[i] == uint16(TokenType.ERC721)
                ? type(IERC721).interfaceId
                : type(IERC1155).interfaceId;
            require(
                IERC165(tokens_[i]).supportsInterface(interface_),
                "token does not support expected interface"
            );

            tokens[tokens_[i]] = TokenType(types[i]);
            emit TokenUpdated(tokens_[i], types[i]);
        }
    }

    /**
     * @param controller_ new controller address
     */
    function setController(address controller_) external onlyOwner {
        controller = controller_;
        emit ControllerUpdated(controller_);
    }

    /**
     * @notice update data to refresh inventory
     */
    function bump() external onlyController {
        available = uint128(inventory.length);
    }

    /**
     * @notice fund the garage sale contract
     */
    function fund() external payable {
        require(msg.value > 0, "fund amount is zero");
        emit Funded(msg.value);
    }

    /**
     * @notice withdraw contract fees
     */
    function withdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "withdraw amount is zero");
        require(amount < address(this).balance, "insufficient balance");
        emit Withdrawn(amount);
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "ether withdraw failed");
    }
}
