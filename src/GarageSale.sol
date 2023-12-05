// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

contract GarageSale {
    // events
    event Sell(address indexed seller, address indexed token, uint256 id);
    event Buy(address indexed buyer, address[] tokens, uint56[] ids);
    event OfferUpdated(uint256 offer);
    event AuctionUpdated(uint256 min, uint256 max, uint256 duration);
    event TakeUpdated(uint256 take);
    event TokenUpdated(address indexed token, bool enabled);
    event ControllerUpdated(address controller);

    // types
    struct Token {
        bool enabled;
        uint64 count;
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
    mapping(address => Token) public tokens;
    uint256 fees;

    /**
     * @notice initialize garage sale contract with reasonable defaults
     */
    constructor() {
        offer = 1e14; // 0.0001 ether
        min = 1e15; // 0.001 ether
        max = 1e17; // 0.1 ether
        duration = 15 * 60; // 15 minutes
        bundle = 4;
        take = 1e2; // 10%
        controller = msg.sender;
    }

    modifier onlyController() {
        require(msg.sender == controller, "sender is not controller");
        _;
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
     * @param take_  new take rate fee
     */
    function setTake(uint256 take_) public onlyController {
        require(take < 1e3, "fee too high");
        take = uint16(take_);
        emit TakeUpdated(take_);
    }

    function setToken(address token, bool enabled) public onlyController {
        // TODO verify token type
        tokens[token].enabled = enabled;
        emit TokenUpdated(token, enabled);
    }

    function setController(address controller_) public {
        // TODO only owner
        controller = controller_;
        emit ControllerUpdated(controller_);
    }
}
