// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract FallbackHandlerTest is SafeTest {
    function test_GetStorageAt() public {
        (ISafeWithFallbackHandler safe,) = deployProxyWithDefaultSetup();

        assertEq(
            safe.getStorageAt(uint256(keccak256("fallback_manager.handler.address")), 2),
            abi.encode(_fallbackHandler, 0)
        );
    }

    function test_Simulate() public {
        (ISafeWithFallbackHandler safe,) = deployProxyWithDefaultSetup();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory returnData = "some return data";

        vm.mockCall(target, callData, returnData);
        assertEq(safe.simulate(target, callData), returnData);
    }

    function test_SimulateWithRevert() public {
        (ISafeWithFallbackHandler safe,) = deployProxyWithDefaultSetup();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory revertMessage = "some revert message";

        vm.mockCallRevert(target, callData, abi.encodeWithSignature("Error(string)", revertMessage));
        vm.expectRevert(revertMessage);
        safe.simulate(target, callData);
    }
}
