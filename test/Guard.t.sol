// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Enum, Guard} from "safe-smart-account/contracts/base/GuardManager.sol";
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

    struct TransactionParameters {
        address to;
        uint256 value;
        bytes data;
        ISafe.Operation operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address payable refundReceiver;
        uint256 nonce;
        bytes signatures;
    }

    function test_TransactionGuard() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address guard = address(0x9a5d);

        vm.mockCall(guard, 0, abi.encodeCall(Guard(guard).supportsInterface, type(Guard).interfaceId), abi.encode(true));
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        address sender = address(0x5e4de5);
        TransactionParameters memory t = TransactionParameters({
            to: address(0x70),
            value: 42 ether,
            data: "some data",
            operation: ISafe.Operation.DELEGATECALL,
            safeTxGas: 0x5afe9a5,
            baseGas: 0xba5e9a5,
            gasPrice: 0x9a5,
            gasToken: address(0x70ce),
            refundReceiver: payable(address(0xf4d)),
            nonce: 1337,
            signatures: ""
        });

        bytes32 txHash = safe.getTransactionHash(
            t.to,
            t.value,
            t.data,
            t.operation,
            t.safeTxGas,
            t.baseGas,
            t.gasPrice,
            t.gasToken,
            t.refundReceiver,
            t.nonce
        );

        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, txHash);
            t.signatures = abi.encodePacked(r, s, v);
        }

        vm.deal(address(safe), t.value);
        vm.store(address(safe), bytes32(uint256(5)), bytes32(t.nonce));
        vm.mockCall(t.gasToken, "", abi.encode(true));

        {
            address _sender = sender;
            TransactionParameters memory _t = t;
            bytes memory checkTransactionCall = abi.encodeCall(
                Guard(guard).checkTransaction,
                (
                    _t.to,
                    _t.value,
                    _t.data,
                    Enum.Operation(uint8(_t.operation)),
                    _t.safeTxGas,
                    _t.baseGas,
                    _t.gasPrice,
                    _t.gasToken,
                    _t.refundReceiver,
                    _t.signatures,
                    _sender
                )
            );
            vm.expectCall(guard, 0, checkTransactionCall);
        }

        vm.expectCall(guard, abi.encodeCall(Guard(guard).checkAfterExecution, (txHash, true)));

        vm.prank(sender);
        bool success = safe.execTransaction(
            t.to,
            t.value,
            t.data,
            t.operation,
            t.safeTxGas,
            t.baseGas,
            t.gasPrice,
            t.gasToken,
            t.refundReceiver,
            t.signatures
        );

        assertTrue(success);
        assertEq(safe.nonce(), t.nonce + 1);
    }

    function test_TransactionGuardReverts() public {
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

        address guard = address(0x9a5d);

        vm.mockCall(guard, 0, abi.encodeCall(Guard(guard).supportsInterface, type(Guard).interfaceId), abi.encode(true));
        vm.prank(address(safe));
        safe.setGuard(address(guard));

        bytes memory revertMessage = "some revert message";

        vm.startPrank(owner.addr);
        bytes memory signatures = abi.encodePacked(uint256(uint160(owner.addr)), bytes32(0), uint8(1));

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(
                guard,
                abi.encodePacked(Guard(guard).checkTransaction.selector),
                abi.encodeWithSignature("Error(string)", revertMessage)
            );

            vm.expectRevert(revertMessage);
            safe.execTransaction(address(0), 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);
        }

        {
            vm.clearMockedCalls();
            vm.mockCallRevert(
                guard,
                abi.encodePacked(Guard(guard).checkAfterExecution.selector),
                abi.encodeWithSignature("Error(string)", revertMessage)
            );

            vm.expectRevert(revertMessage);
            safe.execTransaction(address(0), 0, "", ISafe.Operation.CALL, 0, 0, 0, address(0), address(0), signatures);
        }
    }
}
