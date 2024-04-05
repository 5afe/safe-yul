// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract ExecTransactionTest is SafeTest {
    event ExecutionSuccess(bytes32 indexed txHash, uint256 payment);
    event ExecutionFailure(bytes32 indexed txHash, uint256 payment);

    function test_ExecTransaction() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("someCall(uint256)", 42);
        uint256 nonce = safe.nonce();

        bytes32 txHash =
            safe.getTransactionHash(to, value, data, ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        vm.deal(address(safe), value);

        vm.expectCall(to, value, data);
        vm.expectEmit(address(safe));
        emit ExecutionSuccess(txHash, 0);

        bool success =
            safe.execTransaction(to, value, data, ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);

        assertTrue(success);
        assertEq(safe.nonce(), nonce + 1);
    }

    function test_ExecTransactionSignaturesMishmash() public {
        uint256 n = 6;
        (ISafe safe, Account[] memory owners) = deployProxyWithSetup(n, n);

        address to = address(0x7a59e7);
        uint256 value = 1 ether;
        bytes memory data = abi.encodeWithSignature("someCall(uint256)", 42);
        uint256 nonce = safe.nonce();

        bytes memory txData =
            safe.encodeTransactionData(to, value, data, ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), nonce);
        bytes32 txHash = keccak256(txData);

        address sender;
        bytes memory head;
        bytes memory tail;

        {
            bytes memory sig = "some very signature data that has a lot of non-zero bytes and is over a word";
            bytes memory callData = abi.encodeWithSignature("isValidSignature(bytes,bytes)", txData, sig);
            uint256 s = n * 65 + tail.length;
            vm.mockCall(owners[0].addr, 0, callData, abi.encode(bytes4(callData)));
            head = abi.encodePacked(head, uint256(uint160(owners[0].addr)), s, uint8(0));
            tail = abi.encodePacked(tail, sig.length, sig);
        }

        {
            sender = owners[1].addr;
            head = abi.encodePacked(head, uint256(uint160(owners[1].addr)), bytes32(0), uint8(1));
        }

        {
            vm.prank(owners[2].addr);
            safe.approveHash(txHash);
            head = abi.encodePacked(head, uint256(uint160(owners[2].addr)), bytes32(0), uint8(1));
        }

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owners[3].key, txHash);
            head = abi.encodePacked(head, r, s, v);
        }

        {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(owners[4].key, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash)));
            head = abi.encodePacked(head, r, s, v + 4);
        }

        {
            bytes memory sig = "short signature";
            bytes memory callData = abi.encodeWithSignature("isValidSignature(bytes,bytes)", txData, sig);
            uint256 s = n * 65 + tail.length;
            vm.mockCall(owners[5].addr, 0, callData, abi.encode(bytes4(callData)));
            head = abi.encodePacked(head, uint256(uint160(owners[5].addr)), s, uint8(0));
            tail = abi.encodePacked(tail, sig.length, sig);
        }

        vm.deal(address(safe), value);

        vm.expectCall(to, value, data);
        vm.expectEmit(address(safe));
        emit ExecutionSuccess(txHash, 0);

        vm.prank(sender);
        bool success = safe.execTransaction(
            to, value, data, ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), abi.encodePacked(head, tail)
        );

        assertTrue(success);
        assertEq(safe.nonce(), nonce + 1);
    }

    function test_InsufficientGasReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);

        {
            uint256 safeTxGas = 1;
            bytes32 txHash = safe.getTransactionHash(
                to, 0, "", ISafe.Operation.CALL, safeTxGas, 0, 0, address(0), address(0), safe.nonce()
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
            bytes memory signatures = abi.encodePacked(r, s, v);

            vm.expectRevert("GS010");

            safe.execTransaction{gas: 27750}(
                to, 0, "", ISafe.Operation.CALL, safeTxGas, 0, 0, address(0), address(0), signatures
            );
        }

        {
            uint256 safeTxGas = 1000000;
            bytes32 txHash = safe.getTransactionHash(
                to, 0, "", ISafe.Operation.CALL, safeTxGas, 0, 0, address(0), address(0), safe.nonce()
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
            bytes memory signatures = abi.encodePacked(r, s, v);

            vm.expectRevert("GS010");

            safe.execTransaction{gas: 50000}(
                to, 0, "", ISafe.Operation.CALL, safeTxGas, 0, 0, address(0), address(0), signatures
            );
        }
    }

    function test_NoRevertPropagation() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);

        {
            bytes32 txHash =
                safe.getTransactionHash(to, 0, "", ISafe.Operation.CALL, 1, 0, 0, address(0), address(0), safe.nonce());

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
            bytes memory signatures = abi.encodePacked(r, s, v);

            vm.mockCallRevert(to, "", "some revert data");

            vm.expectEmit(address(safe));
            emit ExecutionFailure(txHash, 0);

            bool success =
                safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 1, 0, 0, address(0), address(0), signatures);

            assertFalse(success);
        }

        {
            bytes32 txHash =
                safe.getTransactionHash(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, address(0), address(0), safe.nonce());

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
            bytes memory signatures = abi.encodePacked(r, s, v);

            vm.mockCallRevert(to, "", "some revert data");

            vm.expectEmit(address(safe));
            emit ExecutionFailure(txHash, 0);

            bool success =
                safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, address(0), address(0), signatures);

            assertFalse(success);
        }
    }

    function test_RevertPropagationWithoutGasParameters() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);

        bytes32 txHash =
            safe.getTransactionHash(to, 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), safe.nonce());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        vm.mockCallRevert(to, "", "some revert data");
        vm.expectRevert("GS013");

        safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);
    }

    function test_HandleEtherPayment() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);
        address payable receiver = payable(address(0x5e1c1e));

        vm.startPrank(owner.addr, receiver);
        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(0), uint8(1));

        vm.deal(address(safe), 1 ether);

        uint256 gasUsed;
        {
            vm.txGasPrice(1);

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);
            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, address(0), receiver, signatures);

            gasUsed = receiver.balance;
            assertGt(gasUsed, 0);
        }

        {
            uint256 baseGas = 10000;
            uint256 gasPrice = 5 gwei;
            uint256 nonce = safe.nonce();
            bytes32 txHash = safe.getTransactionHash(
                to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, address(0), receiver, nonce
            );
            uint256 txGasPrice = 4.2 gwei;

            vm.txGasPrice(txGasPrice);

            vm.expectEmit(address(safe));
            emit ExecutionSuccess(txHash, txGasPrice * (gasUsed + baseGas));

            address payable _receiver = receiver;
            bytes memory _signatures = signatures;
            safe.execTransaction(
                to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, address(0), _receiver, _signatures
            );
        }

        {
            uint256 baseGas = 10000;
            uint256 gasPrice = 5 gwei;
            uint256 nonce = safe.nonce();
            bytes32 txHash = safe.getTransactionHash(
                to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, address(0), address(0), nonce
            );
            uint256 txGasPrice = 100 gwei;

            vm.txGasPrice(txGasPrice);

            vm.expectEmit(address(safe));
            emit ExecutionSuccess(txHash, gasPrice * (gasUsed + baseGas));

            bytes memory _signatures = signatures;
            safe.execTransaction(
                to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, address(0), address(0), _signatures
            );
        }
    }

    function test_HandleTokenPayment() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);
        address token = address(0x70ce4);
        address payable receiver = payable(address(0x5e1c1e));

        vm.startPrank(owner.addr, receiver);
        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(0), uint8(1));

        uint256 gasUsed;
        {
            vm.txGasPrice(1);
            vm.deal(address(safe), 1 ether);

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);
            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, address(0), receiver, signatures);

            gasUsed = receiver.balance;
            assertGt(gasUsed, 0);
        }

        {
            uint256 baseGas = 10000;
            uint256 gasPrice = 5 gwei;
            uint256 nonce = safe.nonce();
            bytes32 txHash =
                safe.getTransactionHash(to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, token, receiver, nonce);

            {
                uint256 payment = gasPrice * (gasUsed + baseGas);
                bytes memory transfer = abi.encodeWithSignature("transfer(address,uint256)", receiver, payment);
                vm.mockCall(token, 0, transfer, abi.encode(true));
                vm.expectCall(token, 0, transfer);
                vm.expectEmit(address(safe));
                emit ExecutionSuccess(txHash, payment);
            }

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, token, receiver, signatures);
        }

        {
            uint256 baseGas = 10000;
            uint256 gasPrice = 5 gwei;
            uint256 nonce = safe.nonce();
            bytes32 txHash =
                safe.getTransactionHash(to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, token, address(0), nonce);

            {
                uint256 payment = gasPrice * (gasUsed + baseGas);
                bytes memory transfer = abi.encodeWithSignature("transfer(address,uint256)", receiver, payment);
                vm.mockCall(token, 0, transfer, "");
                vm.etch(token, hex"c0de");
                vm.expectCall(token, 0, transfer);
                vm.expectEmit(address(safe));
                emit ExecutionSuccess(txHash, payment);
            }

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, baseGas, gasPrice, token, address(0), signatures);
        }
    }

    function test_HandlePaymentFailureReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address to = address(0x7a59e7);
        address token = address(0x70ce4);
        address payable receiver = payable(address(0x5e1c1e));

        vm.txGasPrice(1);
        vm.startPrank(owner.addr, receiver);
        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), uint256(0), uint8(1));

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(receiver, "", "some revert data");

            vm.expectRevert("GS011");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, address(0), receiver, signatures);
        }

        {
            vm.clearMockedCalls();

            vm.expectRevert("GS011");

            safe.execTransaction(
                to, 0, "", ISafe.Operation.CALL, 0, address(safe).balance + 1, 1, address(0), receiver, signatures
            );
        }

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(token, "", "some revert data");

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(token, "", "");
            vm.etch(token, hex"c0de");

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(token, "", abi.encode(true));

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCall(token, "", "");
            vm.etch(token, "");

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCall(token, "", abi.encode(true, uint256(0)));

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCall(token, "", abi.encode(false));

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCall(token, "", abi.encode(type(uint256).max));

            vm.expectRevert("GS012");

            safe.execTransaction(to, 0, "", ISafe.Operation.CALL, 0, 0, 1, token, receiver, signatures);
        }
    }

    function test_TransactionGuard() public {
        revert("todo");
    }

    function test_TransactionGuardReverts() public {
        revert("todo");
    }
}
