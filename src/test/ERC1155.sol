// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    uint256 total;

    constructor() ERC1155("ipfs://mytokenuri") {}

    function mint(address to, uint256 id, uint256 value) external {
        _mint(to, id, value, "");
    }
}
