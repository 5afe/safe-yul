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
        (ISafe safe, Account memory owner) = deployProxyWithDefaultSetup();

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

    function test_TransactionHash() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        address to = address(0x70);
        uint256 value = 42 ether;
        bytes memory data = "some data";
        ISafe.Operation operation = ISafe.Operation.DELEGATECALL;
        uint256 safeTxGas = 0x5afe9a5;
        uint256 baseGas = 0xba5e9a5;
        uint256 gasPrice = 0x9a5;
        address gasToken = address(0x70ce);
        address refundReceiver = address(0xf4d);
        uint256 nonce = 1337;

        assertEq(
            safe.getTransactionHash(
                to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce
            ),
            keccak256(
                abi.encodePacked(
                    hex"1901",
                    keccak256(
                        abi.encode(
                            keccak256("EIP712Domain(uint256 chainId,address verifyingContract)"), block.chainid, safe
                        )
                    ),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
                            ),
                            to,
                            value,
                            keccak256(data),
                            operation,
                            safeTxGas,
                            baseGas,
                            gasPrice,
                            gasToken,
                            refundReceiver,
                            nonce
                        )
                    )
                )
            )
        );
    }

    function test_IsZeroAddressUserOrModule() public {
        (ISafe safe,) = deployProxyWithDefaultSetup();

        address sentinel = address(uint160(1));

        assertFalse(safe.isModuleEnabled(address(0)));
        assertFalse(safe.isModuleEnabled(sentinel));
        assertFalse(safe.isOwner(address(0)));
        assertFalse(safe.isOwner(sentinel));
    }
}
