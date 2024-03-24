// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

contract SafeFallbackAccessor {
    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory result) {
        result = new bytes(length * 32);
        for (uint256 index = 0; index < length; index++) {
            assembly ("memory-safe") {
                let word := sload(add(offset, index))
                mstore(add(add(result, 0x20), mul(index, 0x20)), word)
            }
        }
    }
}
