// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe} from "./ISafe.sol";

interface ISafeFallbackHandler {
    function nonce() external view returns (uint256 value);
    function signedMessages(bytes32 hash) external view returns (bool signed);
    function approvedHashes(address approver, bytes32 hash) external view returns (bool approved);
    function getChainId() external view returns (uint256 chainId);
    function domainSeparator() external view returns (bytes32 value);
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        ISafe.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes memory transactionData);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        ISafe.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes32 transactionHash);

    function isModuleEnabled(address module) external view returns (bool enabled);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory modules, address next);
    function getModules() external view returns (address[] memory modules);

    function getThreshold() external view returns (uint256 threshold);
    function isOwner(address owner) external view returns (bool enabled);
    function getOwners() external view returns (address[] memory owners);

    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
    function simulate(address target, bytes calldata data) external returns (bytes memory result);
}
