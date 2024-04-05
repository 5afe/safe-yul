// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract MiscellaneousTest is SafeTest {
    function test_CheckSignatures() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, hash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        safe.checkSignatures(hash, data, signatures);
    }

    function test_CheckSignaturesMishmash() public {
        uint256 n = 6;
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(n, n);

        bytes memory data = "some very long data that has a lot of non-zero bytes and is over a word";
        bytes32 hash = keccak256(data);

        address sender;
        bytes memory head;
        bytes memory tail;

        {
            bytes memory sig = "some very signature data that has a lot of non-zero bytes and is over a word";
            bytes memory callData = abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, sig);
            vm.mockCall(owners[0].addr, 0, callData, abi.encode(bytes4(callData)));
            head = abi.encodePacked(head, uint256(uint160(owners[0].addr)), uint256(n * 65 + tail.length), uint8(0));
            tail = abi.encodePacked(tail, sig.length, sig);
        }

        {
            sender = owners[1].addr;
            head = abi.encodePacked(head, uint256(uint160(owners[1].addr)), bytes32(0), uint8(1));
        }

        {
            vm.prank(owners[2].addr);
            safe.approveHash(hash);
            head = abi.encodePacked(head, uint256(uint160(owners[2].addr)), bytes32(0), uint8(1));
        }

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owners[3].key, hash);
            head = abi.encodePacked(head, r, s, v);
        }

        {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(owners[4].key, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)));
            head = abi.encodePacked(head, r, s, v + 4);
        }

        {
            bytes memory sig = "short signature";
            bytes memory callData = abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, sig);
            vm.mockCall(owners[5].addr, 0, callData, abi.encode(bytes4(callData)));
            head = abi.encodePacked(head, uint256(uint160(owners[5].addr)), uint256(n * 65 + tail.length), uint8(0));
            tail = abi.encodePacked(tail, sig.length, sig);
        }

        vm.prank(sender);
        safe.checkSignatures(hash, data, abi.encodePacked(head, tail));
    }

    function test_CheckNSignatures() public {
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(3, 3);

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        (uint8 v0, bytes32 r0, bytes32 s0) = vm.sign(owners[0].key, hash);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(owners[1].key, hash);
        bytes memory signatures = abi.encodePacked(r0, s0, v0, r1, s1, v1);

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

    function test_CheckContractSignatureInvalidOffsetReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(32), uint8(0), bytes31(0));

        vm.expectRevert("GS021");
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckContractSignatureLengthOutOfBoundsReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(65), uint8(0), bytes31(0));

        vm.expectRevert("GS022");
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckContractSignatureDataOutOfBoundsReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory signatures =
            abi.encodePacked(uint256(uint160(owner.addr)), uint256(65), uint8(0), uint256(10), bytes9(0));

        vm.expectRevert("GS023");
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckContractSignatureReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);
        bytes memory revertMessage = "some revert message";

        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(65), uint8(0), uint256(0));

        vm.mockCallRevert(
            owner.addr,
            0,
            abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, ""),
            abi.encodeWithSignature("Error(string)", revertMessage)
        );

        vm.expectRevert(revertMessage);
        safe.checkNSignatures(hash, data, signatures, 1);
    }

    function test_CheckContractSignatureInvalidResponseReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        bytes memory data = "data";
        bytes32 hash = keccak256(data);

        bytes memory isValidSignatureData = abi.encodeWithSignature("isValidSignature(bytes,bytes)", data, "");
        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(65), uint8(0), uint256(0));

        vm.mockCall(owner.addr, 0, isValidSignatureData, abi.encode(bytes4(isValidSignatureData), 0));

        vm.expectRevert("GS024");
        safe.checkNSignatures(hash, data, signatures, 1);

        vm.mockCall(owner.addr, 0, isValidSignatureData, abi.encode(bytes4(hex"fefefefe")));

        vm.expectRevert("GS024");
        safe.checkNSignatures(hash, data, signatures, 1);
    }
}
