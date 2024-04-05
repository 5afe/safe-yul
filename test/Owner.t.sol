// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeFallbackAccessor} from "src/accessors/SafeFallbackAccessor.sol";
import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract OwnerTest is SafeTest {
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);

    function test_AddOwner() public {
        (ISafeWithFallbackHandler safe, Account memory owner) = deployProxyWithDefaultSetup();

        address newOwner = address(0xacc0);

        assertFalse(safe.isOwner(newOwner));

        vm.expectEmit(address(safe));
        emit AddedOwner(newOwner);

        vm.prank(address(safe));
        safe.addOwnerWithThreshold(newOwner, 1);

        address[] memory owners = new address[](2);
        // Added owners go to the head of the list
        owners[0] = newOwner;
        owners[1] = owner.addr;
        assertEq(safe.getOwners(), owners);
        assertTrue(safe.isOwner(newOwner));
        assertEq(safe.getThreshold(), 1);
    }

    function test_AddOwnerAndSetThreshold() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        address newOwner = address(0xacc0);

        vm.expectEmit(address(safe));
        emit ChangedThreshold(2);

        vm.prank(address(safe));
        safe.addOwnerWithThreshold(newOwner, 2);

        assertEq(safe.getThreshold(), 2);
    }

    function test_AddOwnerAuthorization() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS031");
        safe.addOwnerWithThreshold(address(0xacc0), 1);
    }

    function test_AddInvalidOwnerReverts() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));

        vm.expectRevert("GS203");
        safe.addOwnerWithThreshold(address(0), 1);

        vm.expectRevert("GS203");
        safe.addOwnerWithThreshold(address(1), 1);

        vm.expectRevert("GS203");
        safe.addOwnerWithThreshold(address(safe), 1);
    }

    function test_AddDuplicateOwnerReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS204");
        vm.prank(address(safe));
        safe.addOwnerWithThreshold(owner.addr, 1);
    }

    function test_RemoveOwner() public {
        (ISafeWithFallbackHandler safe, Account[] memory owners) = deployProxyWithSetup(4, 1);

        {
            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[3].addr);

            vm.prank(address(safe));
            safe.removeOwner(owners[2].addr, owners[3].addr, 1);

            address[] memory remainingOwners = new address[](3);
            remainingOwners[0] = owners[0].addr;
            remainingOwners[1] = owners[1].addr;
            remainingOwners[2] = owners[2].addr;
            assertEq(safe.getOwners(), remainingOwners);
            assertEq(safe.getThreshold(), 1);
        }

        {
            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[1].addr);

            vm.prank(address(safe));
            safe.removeOwner(owners[0].addr, owners[1].addr, 1);

            address[] memory remainingOwners = new address[](2);
            remainingOwners[0] = owners[0].addr;
            remainingOwners[1] = owners[2].addr;
            assertEq(safe.getOwners(), remainingOwners);
            assertEq(safe.getThreshold(), 1);
        }

        {
            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[0].addr);

            vm.prank(address(safe));
            safe.removeOwner(address(1), owners[0].addr, 1);

            address[] memory remainingOwners = new address[](1);
            remainingOwners[0] = owners[2].addr;
            assertEq(safe.getOwners(), remainingOwners);
            assertEq(safe.getThreshold(), 1);
        }
    }

    function test_RemoveOwnerAndSetThreshold() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(3, 1);

        vm.expectEmit(address(safe));
        emit ChangedThreshold(2);

        vm.prank(address(safe));
        safe.removeOwner(address(1), owners[0].addr, 2);

        assertEq(safe.getThreshold(), 2);
    }

    function test_RemoveOwnerAuthorization() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS031");
        safe.removeOwner(address(1), owner.addr, 1);
    }

    function test_RemoveOwnerBelowThresholdReverts() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(2, 1);

        vm.expectRevert("GS201");
        vm.prank(address(safe));
        safe.removeOwner(address(1), owners[0].addr, 2);
    }

    function test_RemoveLastOwnerReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS201");
        vm.prank(address(safe));
        safe.removeOwner(address(1), owner.addr, 1);

        vm.expectRevert("GS202");
        vm.prank(address(safe));
        safe.removeOwner(address(1), owner.addr, 0);
    }

    function test_RemoveInvalidOwnerReverts() public {
        (ISafe safe,) = deployProxyWithSetup(2, 1);

        vm.startPrank(address(safe));

        vm.expectRevert("GS203");
        safe.removeOwner(address(1), address(0), 1);

        vm.expectRevert("GS203");
        safe.removeOwner(address(1), address(1), 1);
    }

    function test_RemoveNonOwnerReverts() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(2, 1);

        vm.startPrank(address(safe));

        vm.expectRevert("GS205");
        safe.removeOwner(address(0xacc0), owners[0].addr, 1);

        vm.expectRevert("GS205");
        safe.removeOwner(owners[0].addr, address(0xacc0), 1);

        vm.expectRevert("GS205");
        safe.removeOwner(owners[1].addr, owners[0].addr, 1);
    }

    function test_SwapOwner() public {
        (ISafeWithFallbackHandler safe, Account[] memory ownerAccounts) = deployProxyWithSetup(3, 1);

        address[] memory owners = new address[](3);
        owners[0] = ownerAccounts[0].addr;
        owners[1] = ownerAccounts[1].addr;
        owners[2] = ownerAccounts[2].addr;
        assertEq(safe.getOwners(), owners);

        {
            address newOwner = address(0xacc0);

            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[0]);
            emit AddedOwner(newOwner);

            vm.prank(address(safe));
            safe.swapOwner(address(1), owners[0], newOwner);

            assertFalse(safe.isOwner(owners[0]));
            owners[0] = newOwner;
            assertEq(safe.getOwners(), owners);
            assertTrue(safe.isOwner(newOwner));
        }

        {
            address newOwner = address(0xacc1);

            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[1]);
            emit AddedOwner(newOwner);

            vm.prank(address(safe));
            safe.swapOwner(owners[0], owners[1], newOwner);

            assertFalse(safe.isOwner(owners[1]));
            owners[1] = newOwner;
            assertEq(safe.getOwners(), owners);
            assertTrue(safe.isOwner(newOwner));
        }

        {
            address newOwner = address(0xacc2);

            vm.expectEmit(address(safe));
            emit RemovedOwner(owners[2]);
            emit AddedOwner(newOwner);

            vm.prank(address(safe));
            safe.swapOwner(owners[1], owners[2], newOwner);

            assertFalse(safe.isOwner(owners[2]));
            owners[2] = newOwner;
            assertEq(safe.getOwners(), owners);
            assertTrue(safe.isOwner(newOwner));
        }
    }

    function test_SwapOwnerAuthorization() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS031");
        safe.swapOwner(address(1), owner.addr, address(0xacc0));
    }

    function test_SwapInvalidOwnerReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));

        vm.expectRevert("GS203");
        safe.swapOwner(address(1), owner.addr, address(0));

        vm.expectRevert("GS203");
        safe.swapOwner(address(1), owner.addr, address(1));

        vm.expectRevert("GS203");
        safe.swapOwner(address(1), owner.addr, address(safe));

        vm.expectRevert("GS203");
        safe.swapOwner(address(1), address(0), address(0xacc0));

        vm.expectRevert("GS203");
        safe.swapOwner(address(1), address(1), address(0xacc0));
    }

    function test_SwapDuplicateOwnerReverts() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(2, 1);

        vm.expectRevert("GS204");
        vm.prank(address(safe));
        safe.swapOwner(address(1), owners[0].addr, owners[1].addr);
    }

    function test_SwapNonOwnerReverts() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(2, 1);

        vm.startPrank(address(safe));

        vm.expectRevert("GS205");
        safe.swapOwner(address(0xacc0), owners[0].addr, address(0xacc0));

        vm.expectRevert("GS205");
        safe.swapOwner(owners[0].addr, address(0xacc0), address(0xacc0));

        vm.expectRevert("GS205");
        safe.swapOwner(owners[1].addr, owners[0].addr, address(0xacc0));
    }

    function test_ChangeThreshold() public {
        (ISafe safe,) = deployProxyWithSetup(3, 1);

        vm.expectEmit(address(safe));
        emit ChangedThreshold(2);

        vm.prank(address(safe));
        safe.changeThreshold(2);

        assertEq(safe.getThreshold(), 2);
    }

    function test_ChangeThresholdGreaterThanOwnerCountReverts() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS201");

        vm.prank(address(safe));
        safe.changeThreshold(2);
    }

    function test_ChangeThresholdToZeroReverts() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS202");

        vm.prank(address(safe));
        safe.changeThreshold(0);
    }
}
