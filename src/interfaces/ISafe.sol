// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

interface ISafe {
    event SafeReceived(address indexed sender, uint256 value);

    function VERSION() external view returns (string memory);

    function setFallbackHandler(address handler) external;

    receive() external payable;
    fallback(bytes calldata input) external returns (bytes memory output);
}
