// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BulkSend {
    function send(address to, address token, uint256[] memory ids) external {
        IERC721 tkn = IERC721(token);
        for (uint256 i; i < ids.length; i++) {
            tkn.safeTransferFrom(msg.sender, to, ids[i]);
        }
    }
}
