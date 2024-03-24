// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.24;

import {ISafe, SafeTest} from "test/SafeTest.sol";

contract FallbackTest is SafeTest {
    event ChangedFallbackHandler(address indexed handler);
    event SafeReceived(address indexed sender, uint256 value);

    function test_Receive() public {
        ISafe safe = deployProxy();

        address sender = 0x0101010101010101010101010101010101010101;
        uint256 value = 42 ether;

        vm.expectEmit(address(safe));
        emit SafeReceived(sender, value);

        vm.deal(sender, value);
        vm.prank(sender);
        (bool success, bytes memory returnData) = payable(safe).call{value: value}("");

        assertTrue(success);
        assertEq(returnData.length, 0);
    }

    function test_RevertOnFallbackWithValue() public {
        ISafe safe = deployProxy();
        (bool success,) = payable(safe).call{value: 1}("data");
        assertFalse(success);
    }

    function test_SetFallbackHandler() public {
        ISafe safe = deployProxy();

        address handler = address(0xfa11bacc);

        vm.expectEmit(address(safe));
        emit ChangedFallbackHandler(handler);

        vm.prank(address(safe));
        safe.setFallbackHandler(handler);

        assertEq(
            vm.load(address(safe), keccak256("fallback_manager.handler.address")), bytes32(uint256(uint160(handler)))
        );
    }

    function test_SetFallbackHandlerMasksAddress() public {
        ISafe safe = deployProxy();

        int256 dirtyHandler = -1;
        address maskedHandler = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;

        vm.expectEmit(address(safe));
        emit ChangedFallbackHandler(maskedHandler);

        vm.prank(address(safe));
        (bool success,) = address(safe).call(abi.encodeWithSelector(safe.setFallbackHandler.selector, (dirtyHandler)));

        assertTrue(success);
        assertEq(
            vm.load(address(safe), keccak256("fallback_manager.handler.address")),
            bytes32(uint256(uint160(maskedHandler)))
        );
    }

    function test_SetFallbackHanderAuthorization() public {
        ISafe safe = deployProxy();

        vm.expectRevert("GS031");
        safe.setFallbackHandler(address(1));
    }

    function test_CannotSetSafeAsFallbackHander() public {
        ISafe safe = deployProxy();

        vm.expectRevert("GS400");
        vm.prank(address(safe));
        safe.setFallbackHandler(address(safe));
    }
}
