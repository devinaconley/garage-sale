// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GarageSale {
    // events
    event Sold(address seller, address token, uint256 id);
    event Purchased(address buyer, address[] tokens, uint56[] ids);

    // fields
    uint256 public offer;
    uint256 public min;
    uint256 public max;
    uint256 public duration;
    mapping(address => bool) public collections;

    // admin configuration
    function setOffer(uint256 offer_) public {
        offer = offer_;
    }

    function setMin(uint256 min_) public {
        min = min_;
    }

    function setMax(uint256 max_) public {
        max = max_;
    }

    function setDuration(uint256 duration_) public {
        duration = duration_;
    }

    function setCollection(address collection, bool enabled) public {
        collections[collection] = enabled;
    }
}
