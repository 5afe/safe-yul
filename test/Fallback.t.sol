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
        bytes memory returnData = callContract(payable(safe), value, "");

        assertEq(returnData, "");
    }

    function test_RevertOnFallbackWithValue() public {
        ISafe safe = deployProxy();
        vm.expectRevert();
        callContract(payable(safe), 1, "data");
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
        callContract(address(safe), abi.encodeWithSelector(safe.setFallbackHandler.selector, (dirtyHandler)));

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

    function test_Fallback() public {
        ISafe safe = deployProxy();

        address sender = 0x0101010101010101010101010101010101010101;
        address handler = address(0xfa11bacc);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", (42));
        bytes memory returnData = "some return data";

        vm.prank(address(safe));
        safe.setFallbackHandler(handler);

        vm.prank(address(sender));
        vm.mockCall(handler, 0, abi.encodePacked(callData, sender), returnData);
        vm.expectCall(handler, abi.encodePacked(callData, sender));
        bytes memory returnedData = callContract(address(safe), callData);

        assertEq(returnData, returnedData);
    }

    function test_FallbackRevert() public {
        ISafe safe = deployProxy();

        address sender = 0x0101010101010101010101010101010101010101;
        address handler = address(0xfa11bacc);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", (42));
        bytes memory revertMessage = "some revert message";

        vm.prank(address(safe));
        safe.setFallbackHandler(handler);

        vm.prank(address(sender));
        vm.mockCallRevert(
            handler, 0, abi.encodePacked(callData, sender), abi.encodeWithSignature("Error(string)", revertMessage)
        );
        vm.expectCall(handler, abi.encodePacked(callData, sender));
        vm.expectRevert(revertMessage);
        callContract(address(safe), callData);
    }
}
