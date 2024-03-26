// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SafeProxyFactory} from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {SafeFallbackHandler} from "src/SafeFallbackHandler.sol";
import {ISafe} from "src/interfaces/ISafe.sol";
import {ISafeWithFallbackHandler} from "src/interfaces/ISafeWithFallbackHandler.sol";

import {BYTECODE} from "./SafeBytecode.sol";

contract SafeTest is Test {
    ISafe internal _singleton;
    SafeFallbackHandler internal _fallbackHandler;
    SafeProxyFactory internal _factory;

    function setUp() public {
        bytes memory bytecode = BYTECODE;
        address payable safe;
        assembly ("memory-safe") {
            safe := create2(0, add(bytecode, 0x20), mload(bytecode), 0x5afe)
        }

        _singleton = ISafe(safe);
        _fallbackHandler = new SafeFallbackHandler();
        _factory = new SafeProxyFactory();
    }

    function deployProxy() internal returns (ISafe proxy) {
        return ISafe(payable(_factory.createProxyWithNonce(address(_singleton), "", 0x5afe)));
    }

    function deployProxyWithFallback() internal returns (ISafeWithFallbackHandler proxy) {
        ISafe safe = deployProxy();

        vm.prank(address(safe));
        safe.setFallbackHandler(address(_fallbackHandler));

        return ISafeWithFallbackHandler(payable(safe));
    }

    function deployProxyWithDefaultSetup() internal returns (ISafeWithFallbackHandler proxy, Account memory owner) {
        owner = makeAccount("chuck norris");
        address[] memory owners = new address[](1);
        owners[0] = owner.addr;
        proxy = ISafeWithFallbackHandler(
            payable(
                _factory.createProxyWithNonce(
                    address(_singleton),
                    abi.encodeCall(
                        _singleton.setup,
                        (owners, 1, address(0), "", address(_fallbackHandler), address(0), 0, address(0))
                    ),
                    0x5afe
                )
            )
        );
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
