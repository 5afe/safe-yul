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
        address safe;
        assembly {
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
        return ISafe(address(_factory.createProxyWithNonce(address(_safe), "", salt)));
    }
}
