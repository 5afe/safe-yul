// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

interface ISafe {
    enum Operation {
        CALL,
        DELEGATECALL
    }

    event SafeReceived(address indexed sender, uint256 value);

    event EnabledModule(address indexed module);
    event DisabledModule(address indexed module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);

    event ChangedFallbackHandler(address indexed handler);

    fallback(bytes calldata input) external returns (bytes memory output);
    receive() external payable;

    function VERSION() external view returns (string memory);

    function setup(
        address[] calldata owners,
        uint256 threshold,
        address setupTo,
        bytes calldata setupData,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address paymentReceiver
    ) external;

    function enableModule(address module) external;
    function disableModule(address prevModule, address module) external;
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Operation operation)
        external
        returns (bool success);
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, Operation operation)
        external
        returns (bool success, bytes memory returnData);

    function setFallbackHandler(address handler) external;

    function setGuard(address guard) external;

    function simulateAndRevert(address target, bytes memory data) external payable;
}
