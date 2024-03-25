// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

contract SafeFallbackAccessor {
    address private constant _SENTINEL_MODULES = address(1);

    address private _singleton;
    mapping(address => address) private _modules;

    function isModuleEnabled(address module) external view returns (bool) {
        return _SENTINEL_MODULES != module && _modules[module] != address(0);
    }

    function getModulesPaginated(address start, uint256 pageSize)
        public
        view
        returns (address[] memory modules, address next)
    {
        require(start == _SENTINEL_MODULES || _modules[start] != address(0), "GS105");
        require(pageSize > 0, "GS106");
        modules = new address[](pageSize);

        uint256 moduleCount = 0;
        next = _modules[start];
        while (next != address(0) && next != _SENTINEL_MODULES && moduleCount < pageSize) {
            modules[moduleCount] = next;
            next = _modules[next];
            moduleCount++;
        }

        if (next != _SENTINEL_MODULES) {
            next = modules[moduleCount - 1];
        }

        assembly ("memory-safe") {
            mstore(modules, moduleCount)
        }
    }

    function getModules() external view returns (address[] memory modules) {
        address next;
        (modules, next) = getModulesPaginated(_SENTINEL_MODULES, 10);
        require(next == address(0) || next == _SENTINEL_MODULES, "GS107");
        return modules;
    }

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
