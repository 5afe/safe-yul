// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

interface ISafe {
    enum Operation {
        CALL,
        DELEGATECALL
    }

    event SafeReceived(address indexed sender, uint256 value);

    event SafeSetup(
        address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler
    );
    event ApproveHash(bytes32 indexed hash, address indexed owner);
    event ExecutionFailure(bytes32 indexed txHash, uint256 payment);
    event ExecutionSuccess(bytes32 indexed txHash, uint256 payment);

    event EnabledModule(address indexed module);
    event DisabledModule(address indexed module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);

    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);

    event ChangedFallbackHandler(address indexed fallbackHandler);

    event ChangedGuard(address indexed guard);

    fallback(bytes calldata input) external returns (bytes memory output);
    receive() external payable;

    function VERSION() external view returns (string memory);

    function nonce() external view returns (uint256 value);
    function approvedHashes(address approver, bytes32 hash) external view returns (bool approved);

    function setup(
        address[] calldata owners,
        uint256 threshold,
        address initializer,
        bytes calldata initializerData,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address paymentReceiver
    ) external;
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
    function checkSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures) external view;
    function checkNSignatures(bytes32 dataHash, bytes memory data, bytes memory signatures, uint256 requiredSignatures)
        external
        view;
    function approveHash(bytes32 hash) external;
    function domainSeparator() external view returns (bytes32 value);
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
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
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes32 transactionHash);

    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Operation operation)
        external
        returns (bool success);
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, Operation operation)
        external
        returns (bool success, bytes memory returnData);
    function isModuleEnabled(address module) external view returns (bool enabled);

    function addOwnerWithThreshold(address owner, uint256 threshold) external;
    function removeOwner(address prevOwner, address owner, uint256 threshold) external;
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function changeThreshold(uint256 threshold) external;
    function getThreshold() external view returns (uint256 threshold);
    function isOwner(address owner) external view returns (bool enabled);

    function setFallbackHandler(address fallbackHandler) external;

    function setGuard(address guard) external;

    function simulateAndRevert(address target, bytes memory data) external payable;
}
