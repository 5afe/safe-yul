// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {ISafe, SafeTest} from "test/SafeTest.sol";

contract SimulateTest is SafeTest {
    function test_SimulateAndRevert() public {
        ISafe safe = deployProxy();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory returnData = "some return data";

        vm.mockCall(target, callData, returnData);
        try safe.simulateAndRevert(target, callData) {
            fail();
        } catch (bytes memory result) {
            assertEq(result, abi.encodePacked(uint256(1), returnData.length, returnData));
        }
    }

    function test_SimulateAndRevertWithRevert() public {
        ISafe safe = deployProxy();

        address target = address(0x7a59e7);
        bytes memory callData = abi.encodeWithSignature("someCall(uint256)", 42);
        bytes memory revertMessage = "some revert message";

        vm.mockCallRevert(target, callData, revertMessage);
        try safe.simulateAndRevert(target, callData) {
            fail();
        } catch (bytes memory result) {
            assertEq(result, abi.encodePacked(uint256(0), revertMessage.length, revertMessage));
        }
    }
}
