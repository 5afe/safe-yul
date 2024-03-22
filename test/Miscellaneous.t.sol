// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.24;

import {ISafe, SafeTest} from "test/SafeTest.sol";

contract MiscellaneousTest is SafeTest {
    function test_Version() public {
        ISafe safe = deployProxy();
        assertEq(safe.VERSION(), "Safe.yul 0.0.1");
    }
}
