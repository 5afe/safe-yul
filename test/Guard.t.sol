// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Guard} from "safe-smart-account/contracts/base/GuardManager.sol";
import {ISafe, SafeTest} from "test/SafeTest.sol";

contract GuardTest is SafeTest {
    event ChangedGuard(address indexed guard);

    function test_SetGuard() public {
        ISafe safe = deployProxy();

        address guard = address(0x9a5d);
        vm.mockCall(guard, 0, abi.encodeCall(Guard(guard).supportsInterface, type(Guard).interfaceId), abi.encode(true));

        vm.expectEmit(address(safe));
        emit ChangedGuard(guard);

        vm.prank(address(safe));
        safe.setGuard(guard);

        assertEq(vm.load(address(safe), keccak256("guard_manager.guard.address")), bytes32(uint256(uint160(guard))));
    }

    function test_UnsetGuard() public {
        ISafe safe = deployProxy();

        vm.expectEmit(address(safe));
        emit ChangedGuard(address(0));

        vm.store(address(safe), keccak256("guard_manager.guard.address"), bytes32(uint256(1)));
        vm.prank(address(safe));
        safe.setGuard(address(0));

        assertEq(vm.load(address(safe), keccak256("guard_manager.guard.address")), bytes32(0));
    }

    function test_SetGuardAuthorization() public {
        ISafe safe = deployProxy();

        vm.expectRevert("GS031");
        safe.setGuard(address(1));
    }

    function test_SetGuardMustSupportInterface() public {
        ISafe safe = deployProxy();

        address guard = address(0x9a5d);

        vm.expectRevert("GS300");
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        vm.mockCallRevert(guard, abi.encodePacked(Guard(guard).supportsInterface.selector), "revert");
        vm.expectRevert("GS300");
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        vm.mockCall(guard, abi.encodePacked(Guard(guard).supportsInterface.selector), abi.encode(false));
        vm.expectRevert("GS300");
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        vm.mockCall(guard, abi.encodePacked(Guard(guard).supportsInterface.selector), abi.encode(true, 0));
        vm.expectRevert("GS300");
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        vm.mockCall(guard, abi.encodePacked(Guard(guard).supportsInterface.selector), abi.encode(type(uint256).max));
        vm.expectRevert("GS300");
        vm.prank(address(safe));
        safe.setGuard(address(guard));
    }
}
