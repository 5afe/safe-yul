// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

interface ISafeFallbackHandler {
    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
    function simulate(address target, bytes calldata callData) external returns (bytes memory result);
}
