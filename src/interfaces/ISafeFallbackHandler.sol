// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

interface ISafeFallbackHandler {
    function isModuleEnabled(address module) external view returns (bool enabled);
    function getModulesPaginated(address start, uint256 pageSize)
        external
        view
        returns (address[] memory modules, address next);
    function getModules() external view returns (address[] memory modules);

    function getStorageAt(uint256 offset, uint256 length) external view returns (bytes memory);
    function simulate(address target, bytes calldata data) external returns (bytes memory result);
}
