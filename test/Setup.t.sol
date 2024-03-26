// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {Guard} from "safe-smart-account/contracts/base/GuardManager.sol";
import {ISafe, ISafeWithFallbackHandler, SafeTest} from "test/SafeTest.sol";

contract SetupTest is SafeTest {
    event SafeSetup(
        address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler
    );

    function test_SingletonSetupReverts() public {
        vm.expectRevert("GS200");
        _singleton.setup(new address[](0), 0, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_Setup() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](3);
        owners[0] = address(0xacc0);
        owners[1] = address(0xacc1);
        owners[2] = address(0xacc2);
        uint256 threshold = 2;

        vm.expectEmit(address(safe));
        emit SafeSetup(address(this), owners, threshold, address(0), address(_fallbackHandler));

        safe.setup(owners, threshold, address(0), "", address(_fallbackHandler), address(0), 0, address(0));

        ISafeWithFallbackHandler safeWithFallback = ISafeWithFallbackHandler(payable(safe));
        assertEq(safeWithFallback.getOwners(), owners);
        assertEq(safeWithFallback.getThreshold(), 2);
    }

    function test_SetupOnIntializedSafeReverts() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();
        vm.expectRevert("GS200");
        safe.setup(new address[](0), 0, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_ThresholdGreaterThanOwnerCountReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](2);
        owners[0] = address(0xacc0);
        owners[1] = address(0xacc1);
        uint256 threshold = 3;

        vm.expectRevert("GS201");
        safe.setup(owners, threshold, address(0), "", address(0), address(0), 0, address(0));

        vm.expectRevert("GS201");
        safe.setup(new address[](0), 1, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_ZeroThresholdReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](2);
        owners[0] = address(0xacc0);
        owners[1] = address(0xacc1);

        vm.expectRevert("GS202");
        safe.setup(owners, 0, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_InvalidOwnerReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](2);
        owners[1] = address(0xacc1);

        owners[0] = address(0);
        vm.expectRevert("GS203");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));

        owners[0] = address(1);
        vm.expectRevert("GS203");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));

        owners[0] = address(safe);
        vm.expectRevert("GS203");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_DuplicateOwnerReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](3);
        owners[0] = address(0xacc0);
        owners[1] = address(0xacc1);

        owners[2] = owners[0];
        vm.expectRevert("GS204");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));

        owners[2] = owners[1];
        vm.expectRevert("GS204");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));

        owners[1] = owners[0];
        vm.expectRevert("GS204");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_IntializedModulesReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);

        // Currently, it is not possible to initialize modules for the account
        // without initalizing other aspects of it that also cause reverts to
        // happen on setup (setting threshold to a non-zero value for example),
        // so we have to cheat a little.
        vm.store(address(safe), keccak256(abi.encode(1, 1)), bytes32(uint256(1)));

        vm.expectRevert("GS100");
        safe.setup(owners, 1, address(0), "", address(0), address(0), 0, address(0));
    }

    function test_SetupWithInitializer() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);

        address initializer = address(0x1417);
        bytes memory initializerData = abi.encodeWithSignature("someCall(uint256)", 42);
        vm.etch(initializer, hex"00c0de");
        vm.expectCall(initializer, 0, initializerData);

        vm.expectEmit(address(safe));
        emit SafeSetup(address(this), owners, 1, initializer, address(0));

        safe.setup(owners, 1, initializer, initializerData, address(0), address(0), 0, address(0));
    }

    function test_SetupWithInitializerWithoutCodeReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);

        address initializer = address(0x1417);

        vm.expectRevert("GS002");
        safe.setup(owners, 1, initializer, "", address(0), address(0), 0, address(0));
    }

    function test_SetupWithInitializerReverts() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);

        address initializer = address(0x1417);
        bytes memory initializerData = abi.encodeWithSignature("someCall(uint256)", 42);
        vm.mockCallRevert(initializer, initializerData, "some revert data");

        vm.expectRevert("GS000");
        safe.setup(owners, 1, initializer, initializerData, address(0), address(0), 0, address(0));
    }

    function test_SetupWithEtherPaymentToOrigin() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);
        uint256 payment = 42 ether;

        address initiator = address(0xf0f0f0);
        address origin = address(0xf1f1f1);

        vm.expectCall(origin, payment, "");
        vm.expectEmit(address(safe));
        emit SafeSetup(initiator, owners, 1, address(0), address(0));

        vm.prank(initiator, origin);
        vm.deal(address(safe), payment);
        safe.setup(owners, 1, address(0), "", address(0), address(0), payment, address(0));
    }

    function test_SetupWithTokenPayment() public {
        ISafe safe = deployProxy();

        address[] memory owners = new address[](1);
        owners[0] = address(0xacc0);
        address token = address(0x70ce4);
        uint256 payment = 1337 ether;
        address receiver = address(0xf1f1f1);

        bytes memory transfer = abi.encodeWithSignature("transfer(address,uint256)", receiver, payment);
        vm.mockCall(token, transfer, abi.encode(true));
        vm.expectCall(token, 0, transfer);

        safe.setup(owners, 1, address(0), "", address(0), token, payment, receiver);
    }
}
