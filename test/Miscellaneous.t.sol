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

    function test_CheckSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, hash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        safe.checkSignatures(hash, data, signatures);
    }

    function test_CheckNSignatures() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(3, 3);

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        Account memory ownerA;
        Account memory ownerB;
        if (owners[0].addr < owners[1].addr) {
            ownerA = owners[0];
            ownerB = owners[1];
        } else {
            ownerA = owners[1];
            ownerB = owners[0];
        }

        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(ownerA.key, hash);
        (uint8 vB, bytes32 rB, bytes32 sB) = vm.sign(ownerB.key, hash);
        bytes memory signatures = abi.encodePacked(rA, sA, vA, rB, sB, vB);

        safe.checkNSignatures(hash, data, signatures, 2);
    }

    function test_CheckZeroSignatures() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        safe.checkNSignatures(hash, data, "", 0);
    }

    function test_CheckEthSignSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(owner.key, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)));
        bytes memory signatures = abi.encodePacked(r, s, v + 4);

        safe.checkSignatures(hash, data, signatures);
    }

    function test_CheckContractSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory contractSignature = "signature";
        bytes memory isValidSignatureData =
            abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, contractSignature);
        bytes memory signatures = abi.encodePacked(
            uint256(uint160(owner.addr)), uint256(65), uint8(0), contractSignature.length, contractSignature
        );

        vm.mockCall(owner.addr, 0, isValidSignatureData, abi.encode(bytes4(isValidSignatureData)));
        vm.expectCall(owner.addr, 0, isValidSignatureData);

        safe.checkSignatures(hash, data, signatures);
    }

    function test_CheckMessageSenderSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), bytes32(0), uint8(1));

        vm.prank(owner.addr);
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckApprovedHashSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), bytes32(0), uint8(1));

        vm.prank(owner.addr);
        safe.approveHash(hash);

        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckInsufficientSignaturesReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        (, bytes32 r, bytes32 s) = vm.sign(owner.key, hash);
        bytes memory signatures = abi.encodePacked(r, s);

        vm.expectRevert("GS020");
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckSignatureForNonOwnerReverts() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        Account memory eve = makeAccount("eve");

        {
            bytes memory contractSignature = "signature";
            bytes memory isValidSignatureData =
                abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, contractSignature);
            bytes memory signatures = abi.encodePacked(
                uint256(uint160(eve.addr)), uint256(65), uint8(0), contractSignature.length, contractSignature
            );

            vm.mockCall(eve.addr, 0, isValidSignatureData, abi.encode(bytes4(isValidSignatureData)));

            vm.expectRevert("GS026");
            safe.checkSignatures(hash, data, signatures);
        }

        {
            bytes memory signatures = abi.encodePacked(uint256(uint160(eve.addr)), bytes32(0), uint8(1));

            vm.expectRevert("GS026");
            vm.prank(eve.addr);
            safe.checkNSignatures(hash, data, signatures, 1);
        }

        {
            bytes memory signatures = abi.encodePacked(uint256(uint160(eve.addr)), bytes32(0), uint8(1));

            vm.prank(address(safe));
            safe.addOwnerWithThreshold(eve.addr, 1);
            vm.prank(eve.addr);
            safe.approveHash(hash);
            vm.prank(address(safe));
            safe.removeOwner(address(1), eve.addr, 1);

            vm.expectRevert("GS026");
            safe.checkNSignatures(hash, data, signatures, 1);
        }

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(eve.key, hash);
            bytes memory signatures = abi.encodePacked(r, s, v);

            vm.expectRevert("GS026");
            safe.checkSignatures(hash, data, signatures);
        }

        {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(eve.key, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)));
            bytes memory signatures = abi.encodePacked(r, s, v + 4);

            vm.expectRevert("GS026");
            safe.checkSignatures(hash, data, signatures);
        }
    }

    function test_CheckSignaturesUnorderedOwnersReverts() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(3, 3);

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        Account memory ownerA;
        Account memory ownerB;
        if (owners[0].addr < owners[1].addr) {
            ownerA = owners[1];
            ownerB = owners[0];
        } else {
            ownerA = owners[0];
            ownerB = owners[1];
        }

        (uint8 vA, bytes32 rA, bytes32 sA) = vm.sign(ownerA.key, hash);
        (uint8 vB, bytes32 rB, bytes32 sB) = vm.sign(ownerB.key, hash);
        bytes memory signatures = abi.encodePacked(rA, sA, vA, rB, sB, vB);

        vm.expectRevert("GS026");
        safe.checkNSignatures(hash, data, signatures, 2);
    }

    // TODO:
    // - GS027
    // - GS021
    // - GS022
    // - GS023
    // - GS024 (x2)
    // - isValidSignature@reverts
}
