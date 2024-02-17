// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/DoubleEndedQueue.sol)
// Modified by Pandora Labs to support native uint256 operations
pragma solidity ^0.8.20;

library GeneralUrilLib {
    function random(string memory input, address sender) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input, block.timestamp, block.basefee, sender)));
    }
}
