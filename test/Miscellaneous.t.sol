// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract MiscellaneousTest is SafeTest {
    event ApproveHash(bytes32 indexed hash, address indexed owner);

    function test_Version() public {
        ISafe safe = deployProxy();
        assertEq(safe.VERSION(), "0.0.1+Yul");
    }

    function test_ApproveHash() public {
        (ISafeWithFallbackHandler safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes32 hash = keccak256("Safe");

        assertFalse(safe.approvedHashes(owner.addr, hash));

        vm.expectEmit(address(safe));
        emit ApproveHash(hash, owner.addr);

        vm.prank(owner.addr);
        safe.approveHash(hash);

        assertTrue(safe.approvedHashes(owner.addr, hash));
    }

    function test_ApproveHashAuthorization() public {
        ISafe safe = deployProxy();

        vm.expectRevert("GS030");
        safe.approveHash(bytes32(0));
    }
}
