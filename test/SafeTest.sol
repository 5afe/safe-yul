// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeFallbackHandler} from "src/SafeFallbackHandler.sol";
import {ISafe} from "src/interfaces/ISafe.sol";
import {ISafeWithFallbackHandler} from "src/interfaces/ISafeWithFallbackHandler.sol";

import {BYTECODE} from "./SafeBytecode.sol";

contract SafeTest is Test {
    ISafe internal _singleton;
    SafeFallbackHandler internal _handler;
    SafeProxyFactory internal _factory;

    function setUp() public {
        bytes memory bytecode = BYTECODE;
        address payable safe;
        assembly ("memory-safe") {
            safe := create2(0, add(bytecode, 0x20), mload(bytecode), 0x5afe)
        }
        console2.logBytes(bytecode);
        console2.log("safe", safe);

        _singleton = ISafe(safe);
        _handler = new SafeFallbackHandler();
        _factory = new SafeProxyFactory();
    }

    function deployProxy() internal returns (ISafe proxy) {
        return deployProxy(0x5afe);
    }

    function deployProxy(uint256 salt) internal returns (ISafe proxy) {
        return ISafe(
            payable(
                _factory.createProxyWithNonce(
                    address(_singleton),
                    abi.encodeCall(
                        _singleton.setup, (new address[](0), 0, address(0), "", address(0), address(0), 0, address(0))
                    ),
                    salt
                )
            )
        );
    }

    function deployProxyWithFallback() internal returns (ISafeWithFallbackHandler proxy) {
        return deployProxyWithFallback(0x5afe);
    }

    function deployProxyWithFallback(uint256 salt) internal returns (ISafeWithFallbackHandler proxy) {
        ISafe safe = deployProxy(salt);

        vm.prank(address(safe));
        safe.setFallbackHandler(address(_handler));

        return ISafeWithFallbackHandler(payable(safe));
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
