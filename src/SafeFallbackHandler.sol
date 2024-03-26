// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeFallbackAccessor} from "./accessors/SafeFallbackAccessor.sol";
import {ISafe} from "./interfaces/ISafe.sol";
import {ISafeFallbackHandler} from "./interfaces/ISafeFallbackHandler.sol";

contract SafeFallbackHandler is ISafeFallbackHandler {
    SafeFallbackAccessor private immutable _ACCESSOR;

    constructor() {
        _ACCESSOR = new SafeFallbackAccessor();
    }

    function isModuleEnabled(address) external view returns (bool) {
        _fallbackToAccessor();
    }

    function getModulesPaginated(address, uint256) external view returns (address[] memory, address) {
        _fallbackToAccessor();
    }

    function getModules() external view returns (address[] memory) {
        _fallbackToAccessor();
    }

    function getThreshold() external view returns (uint256) {
        _fallbackToAccessor();
    }

    function isOwner(address) external view returns (bool) {
        _fallbackToAccessor();
    }

    function getOwners() external view returns (address[] memory) {
        _fallbackToAccessor();
    }

    function getStorageAt(uint256, uint256) external view returns (bytes memory) {
        _fallbackToAccessor();
    }

    function simulate(address target, bytes calldata data) public returns (bytes memory result) {
        bytes memory simulationCallData = abi.encodeCall(ISafe.simulateAndRevert, (target, data));

        assembly ("memory-safe") {
            pop(call(gas(), caller(), 0, add(simulationCallData, 0x20), mload(simulationCallData), 0x00, 0x20))

            let responseSize := sub(returndatasize(), 0x20)
            result := mload(0x40)
            mstore(0x40, add(result, responseSize))
            returndatacopy(result, 0x20, responseSize)

            if iszero(mload(0x00)) { revert(add(result, 0x20), mload(result)) }
        }
    }

    function _simulateAccessor(bytes calldata data) internal view returns (bytes memory result) {
        function(address, bytes calldata) internal returns (bytes memory) _simulate = simulate;
        function(address, bytes calldata) internal view returns (bytes memory) _simulateView;
        assembly ("memory-safe") {
            _simulateView := _simulate
        }

        return _simulateView(address(_ACCESSOR), data);
    }

    function _fallbackToAccessor() internal view {
        bytes memory result = _simulateAccessor(msg.data);
        assembly ("memory-safe") {
            return(add(result, 0x20), mload(result))
        }
    }
}
