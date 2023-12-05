// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 total;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    function mint(address to, uint256 count) external {
        for (uint256 i; i < count; i++) {
            _mint(to, total + i + 1);
        }
        total += count;
    }
}
