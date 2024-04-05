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

    function deployProxyWithDefaultSetup() internal returns (ISafeWithFallbackHandler proxy, Account memory owner) {
        Account[] memory owners;
        (proxy, owners) = deployProxyWithSetup(1, 1);
        owner = owners[0];
    }

    function deployProxyWithSetup(uint256 ownerCount, uint256 threshold)
        internal
        returns (ISafeWithFallbackHandler proxy, Account[] memory owners)
    {
        owners = new Account[](ownerCount);
        Account memory temp;
        for (uint256 i = 0; i < ownerCount; i++) {
            owners[i] = makeAccount(string(abi.encodePacked("chuck norris ", uint8(i + 0x30))));
            for (uint256 j = i; j > 0; j--) {
                if (owners[j].addr > owners[j - 1].addr) {
                    break;
                }
                temp = owners[j - 1];
                owners[j - 1] = owners[j];
                owners[j] = temp;
            }
        }

        address[] memory ownerAddrs = new address[](ownerCount);
        for (uint256 i = 0; i < ownerCount; i++) {
            ownerAddrs[i] = owners[i].addr;
        }

        proxy = ISafeWithFallbackHandler(
            payable(
                _factory.createProxyWithNonce(
                    address(_singleton),
                    abi.encodeCall(
                        _singleton.setup,
                        (ownerAddrs, threshold, address(0), "", address(_fallbackHandler), address(0), 0, address(0))
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
