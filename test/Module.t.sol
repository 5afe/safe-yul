// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeFallbackAccessor} from "src/accessors/SafeFallbackAccessor.sol";
import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract ModuleTest is SafeTest {
    event EnabledModule(address indexed module);
    event DisabledModule(address indexed module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);

    function test_EnableModule() public {
        (ISafeWithFallbackHandler safe,) = deployProxyWithDefaultSetup();

        address[] memory modules = new address[](3);
        for (uint256 i = 0; i < modules.length; i++) {
            modules[i] = address(uint160(0xd000 | i));
        }

        for (uint256 i = modules.length; i > 0; i--) {
            address module = modules[i - 1];

            assertFalse(safe.isModuleEnabled(module));

            vm.expectEmit(address(safe));
            emit EnabledModule(module);

            vm.prank(address(safe));
            safe.enableModule(module);

            assertTrue(safe.isModuleEnabled(module));
        }

        assertEq(safe.getModules(), modules);
    }

    function test_EnableModuleAuthorization() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS031");
        safe.enableModule(address(0xd001));
    }

    function test_EnableModuleRevertsOnInvalidParameter() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));
        vm.expectRevert("GS101");
        safe.enableModule(address(0));
        vm.expectRevert("GS101");
        safe.enableModule(address(1));
    }

    function test_EnableModuleRevertsForAlreadyEnabledModule() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));
        safe.enableModule(address(0xd001));
        vm.expectRevert("GS102");
        safe.enableModule(address(0xd001));
    }

    function test_DisableModule() public {
        (ISafeWithFallbackHandler safe,) = deployProxyWithDefaultSetup();

        address[] memory modules = new address[](3);
        for (uint256 i = modules.length; i > 0; i--) {
            modules[i - 1] = address(uint160(0xd000 | i - 1));

            vm.prank(address(safe));
            safe.enableModule(modules[i - 1]);
        }

        vm.expectEmit(address(safe));
        emit DisabledModule(address(0xd001));

        vm.prank(address(safe));
        safe.disableModule(address(0xd000), address(0xd001));

        {
            modules = new address[](2);
            modules[0] = address(0xd000);
            modules[1] = address(0xd002);
            assertEq(safe.getModules(), modules);
        }

        for (uint256 i = 0; i < modules.length; i++) {
            vm.expectEmit(address(safe));
            emit DisabledModule(modules[i]);

            vm.prank(address(safe));
            safe.disableModule(address(1), modules[i]);
        }

        assertEq(safe.getModules(), new address[](0));
    }

    function test_DisableModuleAuthorization() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.expectRevert("GS031");
        safe.disableModule(address(1), address(0xd001));
    }

    function test_DisableModuleRevertsOnInvalidParameter() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));
        vm.expectRevert("GS101");
        safe.disableModule(address(1), address(0));
        vm.expectRevert("GS101");
        safe.disableModule(address(1), address(1));
    }

    function test_DisableModuleRevertsForNonEnabledModule() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        vm.startPrank(address(safe));
        safe.enableModule(address(0xd001));
        vm.expectRevert("GS103");
        safe.disableModule(address(1), address(0xd002));
    }

    function test_ExecuteFromModuleCall() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        address module = address(0xd001);
        address target = address(0x7a59e7);
        uint256 value = 42 ether;
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory returnData = abi.encode(0x1337);

        vm.deal(address(safe), value);
        vm.prank(address(safe));
        safe.enableModule(module);

        vm.mockCall(target, value, callData, returnData);
        vm.startPrank(module);

        vm.expectCall(target, value, callData);
        vm.expectEmit(address(safe));
        emit ExecutionFromModuleSuccess(module);
        bool success = safe.execTransactionFromModule(target, value, callData, ISafe.Operation.CALL);

        assertTrue(success);

        vm.expectCall(target, value, callData);
        vm.expectEmit(address(safe));
        emit ExecutionFromModuleSuccess(module);
        bytes memory returnedData;
        (success, returnedData) =
            safe.execTransactionFromModuleReturnData(target, value, callData, ISafe.Operation.CALL);

        assertTrue(success);
        assertEq(returnedData, returnData);
    }

    function test_ExecuteFromModuleRevertCall() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        address module = address(0xd001);
        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory revertData = abi.encodeWithSignature("Error(string)", "some revert message");

        vm.prank(address(safe));
        safe.enableModule(module);

        vm.mockCallRevert(target, callData, revertData);
        vm.startPrank(module);

        vm.expectCall(target, callData);
        vm.expectEmit(address(safe));
        emit ExecutionFromModuleFailure(module);
        bool success = safe.execTransactionFromModule(target, 0, callData, ISafe.Operation.CALL);

        assertFalse(success);

        vm.expectCall(target, callData);
        vm.expectEmit(address(safe));
        emit ExecutionFromModuleFailure(module);
        bytes memory returnedData;
        (success, returnedData) = safe.execTransactionFromModuleReturnData(target, 0, callData, ISafe.Operation.CALL);

        assertFalse(success);
        assertEq(returnedData, revertData);
    }

    function test_ExecuteFromModuleDelegatecall() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();
        SafeFallbackAccessor accessor = new SafeFallbackAccessor();

        address module = address(0xd001);
        // NOTE: value is ingored for delegate calls.
        uint256 value = type(uint256).max;

        vm.prank(address(safe));
        safe.enableModule(module);

        vm.prank(module);
        (bool success, bytes memory returnData) = safe.execTransactionFromModuleReturnData(
            address(accessor), value, abi.encodeCall(accessor.getModules, ()), ISafe.Operation.DELEGATECALL
        );

        address[] memory modules = new address[](1);
        modules[0] = module;

        assertTrue(success);
        assertEq(returnData, abi.encode(modules));
    }
}
