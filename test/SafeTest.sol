// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {ISafe} from "src/interfaces/ISafe.sol";

import {BYTECODE} from "./SafeBytecode.sol";

contract SafeTest is Test {
    ISafe internal _safe;
    SafeProxyFactory _factory;

    function setUp() public {
        bytes memory bytecode = BYTECODE;
        address payable safe;
        assembly ("memory-safe") {
            safe := create2(0, add(bytecode, 0x20), mload(bytecode), 0x5afe)
        }
        console2.logBytes(bytecode);
        console2.log("safe", safe);

        _safe = ISafe(safe);
        _factory = new SafeProxyFactory();
    }

    function deployProxy() internal returns (ISafe proxy) {
        return deployProxy(0x5afe);
    }

    function deployProxy(uint256 salt) internal returns (ISafe proxy) {
        return ISafe(payable(_factory.createProxyWithNonce(address(_safe), "", salt)));
    }

    function callContract(address target, bytes memory callData) internal returns (bytes memory returnData) {
        return callContract(payable(target), 0, callData);
    }

    function callContract(address payable target, uint256 value, bytes memory callData)
        internal
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) = target.call{value: value}(callData);
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}
