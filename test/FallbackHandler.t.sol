// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeFallbackHandler} from "src/SafeFallbackHandler.sol";
import {ISafeWithFallbackHandler} from "src/interfaces/ISafeWithFallbackHandler.sol";
import {ISafe, SafeTest} from "test/SafeTest.sol";

contract FallbackHandlerTest is SafeTest {
    SafeFallbackHandler internal _handler;

    function setUp() public override {
        SafeTest.setUp();
        _handler = new SafeFallbackHandler();
    }

    function deployProxyWithFallback() internal returns (ISafeWithFallbackHandler proxy) {
        ISafe safe = deployProxy();

        vm.prank(address(safe));
        safe.setFallbackHandler(address(_handler));

        return ISafeWithFallbackHandler(payable(safe));
    }

    function test_GetStorageAt() public {
        ISafeWithFallbackHandler safe = deployProxyWithFallback();

        assertEq(safe.getStorageAt(uint256(keccak256("fallback_manager.handler.address")), 2), abi.encode(_handler, 0));
    }

    function test_Simulate() public {
        ISafeWithFallbackHandler safe = deployProxyWithFallback();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", (42));
        bytes memory returnData = "some return data";

        vm.mockCall(target, callData, returnData);
        assertEq(safe.simulate(target, callData), returnData);
    }

    function test_SimulateWithRevert() public {
        ISafeWithFallbackHandler safe = deployProxyWithFallback();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", (42));
        bytes memory revertMessage = "some revert message";

        vm.mockCallRevert(target, callData, revertMessage);
        vm.expectRevert(revertMessage);
        safe.simulate(target, callData);
    }
}
