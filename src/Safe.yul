// TODO(nlordell):
// - Comment code
// - Don't use string literals where possible, they make the code bigger

// Preprocessor wishlist:
// - #define nonpayable() if callvalue() { revert(0x00, 0x00) }
// - #define EVENT_NAME 0x...
// - #define SENTINEL_MODULES 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f
// - #define THRESHOLD 4
// - #define IS_L2_SAFE ...

object "Safe" {
  code {
    sstore(4, 1)
    let size := datasize("runtime")
    datacopy(0x00, dataoffset("runtime"), size)
    return(0x00, size)
  }

  object "runtime" {
    code {
      switch shr(224, calldataload(0x00))
      case 0xffa1ad74 { VERSION() }
      case 0xb63e800d { setup() }
      case 0x610b5925 { enableModule() }
      case 0xe009cfde { disableModule() }
      case 0x468721a7 { execTransactionFromModule() }
      case 0x5229073f { execTransactionFromModuleReturnData() }
      case 0x0d582f13 { addOwnerWithThreshold() }
      case 0xf8dc5dd9 { removeOwner() }
      case 0xe318b52b { swapOwner() }
      case 0x694e80c3 { changeThreshold() }
      case 0xf08a0323 { setFallbackHandler() }
      case 0xe19a9dd9 { setGuard() }
      case 0xb4faba09 { simulateAndRevert() }
      default {
        if iszero(calldatasize()) {
          receive()
        }
        fallback()
      }

      function VERSION() {
        if callvalue() { revert(0x00, 0x00) }

        mstore(0x00, 0x20)
        mstore(0x3f, "\x0eSafe.yul 0.0.1")
        return(0x00, 0x60)
      }

      function setup() {
        if sload(4) { _error("GS200") }

        let owners := add(calldataload(0x04), 0x04)
        let ownersCount := calldataload(owners)
        let ownersSize := shl(5, ownersCount)
        let threshold := calldataload(0x24)
        {
          if gt(threshold, ownersCount) { _error("GS201") }
          if iszero(threshold) { _error("GS202") }
          let previousOwner := 1
          for {
            let ownerPtr := add(owners, ownersSize)
          } gt(ownerPtr, owners) {
            ownerPtr := sub(ownerPtr, 0x20)
          } {
            let owner := calldataload(ownerPtr)
            if or(lt(owner, 2), eq(owner, address())) { _error("GS203") }
            mstore(0x00, owner)
            mstore(0x20, 2)
            let slot := keccak256(0x00, 0x40)
            if sload(slot) { _error("GS204") }
            sstore(slot, previousOwner)
            previousOwner := owner
          }
          // owners[SENTINEL_OWNERS]
          sstore(
            0xe90b7bceb6e7df5418fb78d8ee546e97c83a08bbccc01a0644d599ccd2a7c2e0,
            previousOwner
          )
          sstore(3, ownersCount)
          sstore(4, threshold)
        }

        let fallbackHandler := shr(96, calldataload(0x90))
        if fallbackHandler {
          _internalSetFallbackHandler(fallbackHandler)
        }

        let initializer := shr(96, calldataload(0x50))
        {
          let sentinel := 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f
          if sload(sentinel) { _error("GS100") }
          sstore(sentinel, 1)
          if initializer {
            let data := add(calldataload(0x64), 0x04)
            let dataLength := calldataload(data)
            calldatacopy(0x00, add(data, 0x20), dataLength)
            if iszero(
              delegatecall(
                gas(),
                initializer,
                0x00, dataLength,
                0x00, 0x00
              )
            ) {
              _error("GS000")
            }
            if iszero(returndatasize()) {
              if iszero(extcodesize(initializer)) { _error("GS002") }
            }
          }
        }

        let payment := calldataload(0xc4)
        if payment {
          _handlePayment(
            shr(96, calldataload(0xb0)),
            payment,
            shr(96, calldataload(0xf0))
          )
        }

        // event SafeSetup(address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler)
        mstore(0x00, 0x80)
        mstore(0x20, threshold)
        mstore(0x40, initializer)
        mstore(0x60, fallbackHandler)
        calldatacopy(0x80, owners, add(ownersSize, 0x20))
        log2(
          0x00, add(ownersSize, 0xa0),
          0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8,
          caller()
        )
        stop()
      }

      function enableModule() {
        _authorized()

        let module := shr(96, calldataload(0x10))
        if lt(module, 2) { _error("GS101") }

        mstore(0x00, module)
        mstore(0x20, 1)
        let slot := keccak256(0x00, 0x40)
        if sload(slot) { _error("GS102") }

        let sentinel := 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f
        sstore(slot, sload(sentinel))
        sstore(sentinel, module)
        // event EnabledModule(address indexed module)
        log2(
          0x00, 0x00,
          0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440,
          module
        )
        stop()
      }

      function disableModule() {
        _authorized()

        let module := shr(96, calldataload(0x30))
        if lt(module, 2) { _error("GS101") }

        mstore(0x20, 1)
        mstore(0x00, shr(96, calldataload(0x10)))
        let prevSlot := keccak256(0x00, 0x40)
        if xor(sload(prevSlot), module) { _error("GS103") }

        mstore(0x00, module)
        let slot := keccak256(0x00, 0x40)
        sstore(prevSlot, sload(slot))
        sstore(slot, 0)
        // event DisabledModule(address indexed module)
        log2(
          0x00, 0x00,
          0xaab4fa2b463f581b2b32cb3b7e3b704b9ce37cc209b5fb4d77e593ace4054276,
          module
        )
        stop()
      }

      function execTransactionFromModule() {
        mstore(0x00, _execTransactionFromModule())
        return(0x00, 0x20)
      }

      function execTransactionFromModuleReturnData() {
        mstore(0x00, _execTransactionFromModule())
        mstore(0x20, 0x40)
        mstore(0x40, returndatasize())
        returndatacopy(0x60, 0x00, returndatasize())
        return(0x00, add(returndatasize(), 0x60))
      }

      function addOwnerWithThreshold() {
        _authorized()

        let owner := shr(96, calldataload(0x10))
        if or(lt(owner, 2), eq(owner, address())) { _error("GS203") }

        mstore(0x00, owner)
        mstore(0x20, 2)
        let slot := keccak256(0x00, 0x40)
        if sload(slot) { _error("GS204") }

        let sentinel := 0xe90b7bceb6e7df5418fb78d8ee546e97c83a08bbccc01a0644d599ccd2a7c2e0
        sstore(slot, sload(sentinel))
        sstore(sentinel, owner)
        sstore(3, add(sload(3), 1))
        // event AddedOwner(address indexed owner)
        log2(
          0x00, 0x00,
          0x9465fa0c962cc76958e6373a993326400c1c94f8be2fe3a952adfa7f60b2ea26,
          owner
        )
        let threshold := calldataload(0x24)
        if xor(threshold, sload(4)) {
          _changeThreshold(threshold)
        }
        stop()
      }

      function removeOwner() {
        _authorized()

        let ownerCount := sub(sload(3), 1)
        let threshold := calldataload(0x44)
        if lt(ownerCount, threshold) { _error("GS201") }

        let owner := shr(96, calldataload(0x30))
        if lt(owner, 2) { _error("GS203") }

        mstore(0x00, shr(96, calldataload(0x10)))
        mstore(0x20, 2)
        let prevSlot := keccak256(0x00, 0x40)
        if xor(sload(prevSlot), owner) { _error("GS205") }

        mstore(0x00, owner)
        let slot := keccak256(0x00, 0x40)
        sstore(prevSlot, sload(slot))
        sstore(slot, 0)
        sstore(3, ownerCount)
        // event RemovedOwner(address indexed owner)
        log2(
          0x00, 0x00,
          0xf8d49fc529812e9a7c5c50e69c20f0dccc0db8fa95c98bc58cc9a4f1c1299eaf,
          owner
        )
        if xor(threshold, sload(4)) {
          _changeThreshold(threshold)
        }
        stop()
      }

      function swapOwner() {
        _authorized()

        let newOwner := shr(96, calldataload(0x50))
        if or(lt(newOwner, 2), eq(newOwner, address())) { _error("GS203") }

        mstore(0x00, newOwner)
        mstore(0x20, 2)
        let newSlot := keccak256(0x00, 0x40)
        if sload(newSlot) { _error("GS204") }

        let oldOwner := shr(96, calldataload(0x30))
        if lt(oldOwner, 2) { _error("GS203") }

        mstore(0x00, shr(96, calldataload(0x10)))
        let prevSlot := keccak256(0x00, 0x40)
        if xor(sload(prevSlot), oldOwner) { _error("GS205") }

        mstore(0x00, oldOwner)
        let oldSlot := keccak256(0x00, 0x40)
        sstore(newSlot, sload(oldSlot))
        sstore(prevSlot, newOwner)
        sstore(oldSlot, 0)
        // event RemovedOwner(address indexed owner)
        log2(
          0x00, 0x00,
          0xf8d49fc529812e9a7c5c50e69c20f0dccc0db8fa95c98bc58cc9a4f1c1299eaf,
          oldOwner
        )
        // event AddedOwner(address indexed owner)
        log2(
          0x00, 0x00,
          0x9465fa0c962cc76958e6373a993326400c1c94f8be2fe3a952adfa7f60b2ea26,
          newOwner
        )
      }

      function changeThreshold() {
        _authorized()

        _changeThreshold(calldataload(0x04))
        stop()
      }

      function setFallbackHandler() {
        _authorized()

        let fallbackHandler := shr(96, calldataload(0x10))
        _internalSetFallbackHandler(fallbackHandler)
        // event ChangedFallbackHandler(address indexed fallbackHandler)
        log2(
          0x00, 0x00,
          0x5ac6c46c93c8d0e53714ba3b53db3e7c046da994313d7ed0d192028bc7c228b0,
          fallbackHandler
        )
        stop()
      }

      function setGuard() {
        _authorized()

        let guard := shr(96, calldataload(0x10))
        if guard {
          // guard.supportsInterface(type(Guard).interfaceId)
          mstore(0x00, hex"01ffc9a7e6d7a83a")
          if or(
            or(
              xor(returndatasize(), 0x20),
              xor(mload(0x00), 1)
            ),
            iszero(staticcall(gas(), guard, 0x00, 0x24, 0x00, 0x20))
          ) {
            _error("GS300")
          }
        }
        // GUARD_STORAGE_SLOT
        sstore(
          0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8,
          guard
        )
        // event ChangedGuard(address indexed guard)
        log2(
          0x00, 0x00,
          0x1151116914515bc0891ff9047a6cb32cf902546f83066499bcf8ba33d2353fa2,
          guard
        )
        stop()
      }

      function simulateAndRevert() {
        let data := add(calldataload(0x24), 0x04)
        let dataLength := calldataload(data)
        calldatacopy(0x00, add(data, 0x20), dataLength)
        mstore(
          0x00,
          delegatecall(
            gas(),
            calldataload(0x04),
            0x00, dataLength,
            0x00, 0x00
          )
        )
        mstore(0x20, returndatasize())
        returndatacopy(0x40, 0x00, returndatasize())
        revert(0x00, add(returndatasize(), 0x40))
      }

      function receive() {
        // event SafeReceived(address indexed sender, uint256 value)
        mstore(0x00, callvalue())
        log2(
          0x00, 0x20,
          0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d,
          caller()
        )
        stop()
      }

      function fallback() {
        if callvalue() { revert(0x00, 0x00) }

        calldatacopy(0x00, 0x00, calldatasize())
        mstore(calldatasize(), shl(96, caller()))
        let success := call(
          gas(),
          // FALLBACK_HANDLER_STORAGE_SLOT
          sload(0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5),
          0,
          0x00, add(calldatasize(), 0x14),
          0x00, 0x00
        )
        returndatacopy(0x00, 0x00, returndatasize())

        if success {
          return(0x00, returndatasize())
        }
        revert(0x00, returndatasize())
      }

      function _error(code) {
        mstore(0x00, hex"08c379a0")
        mstore(0x04, 0x20)
        mstore(0x24, 0x05)
        mstore(0x44, code)
        revert(0x00, 0x64)
      }

      function _authorized() {
        if callvalue() { revert(0x00, 0x00) }
        if iszero(eq(caller(), address())) { _error("GS031") }
      }

      function _execTransactionFromModule() -> success {
        if callvalue() { revert(0x00, 0x00) }

        mstore(0x00, caller())
        mstore(0x20, 1)
        let slot := keccak256(0x00, 0x40)
        if lt(caller(), 2) { _error("GS104") }

        success := _execute(
          calldataload(0x04),
          calldataload(0x24),
          add(calldataload(0x44), 0x04),
          calldataload(0x64),
          // Can't use gas() here because of ERC-4337.
          0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        )
        // event ExecutionFromModuleSuccess(address indexed module)
        // event ExecutionFromModuleFailure(address indexed module)
        log2(
          0x00, 0x00,
          or(
            mul(
              success,
              0x6895c13664aa4f67288b25d7a21d7aaa34916e355fb9b6fae0a139a9085becb8
            ),
            mul(
              iszero(success),
              0xacd2c8702804128fdb0db2bb49f6d127dd0181c13fd45dbfe16de0930e2bd375
            )
          ),
          caller()
        )
      }

      function _execute(to, value, data, operation, gasLimit) -> success {
        let dataLength := calldataload(data)
        calldatacopy(0x00, add(data, 0x20), dataLength)

        switch operation
        case 0 { success := call(gasLimit, to, value, 0x00, dataLength, 0x00, 0x00) }
        case 1 { success := delegatecall(gasLimit, to, 0x00, dataLength, 0x00, 0x00) }
        default { revert(0x00, 0x00) }
      }

      function _handlePayment(token, payment, receiver) {
        receiver := or(receiver, mul(iszero(receiver), origin()))
        switch token
        case 0 {
          if iszero(call(2300, receiver, payment, 0x00, 0x00, 0x00, 0x00)) {
            _error("GS011")
          }
        }
        default {
          // token.transfer(receiver, payment)
          mstore(0x00, hex"a9059cbb")
          mstore(0x04, receiver)
          mstore(0x24, payment)
          let success := call(
            sub(gas(), 10000),
            token,
            0,
            0x00, 0x44,
            0x00, 0x20
          )
          switch returndatasize()
          case 0x00 {
            success := mul(success, extcodesize(token))
          }
          case 0x20 {
            success := and(success, eq(mload(0x00), 1))
          }
          default {
            success := 0
          }
          if iszero(success) { _error("GS012") }
        }
      }

      /*
      function _handlePayment(gasUsed, baseGas, gasPrice, token, receiver) {
        receiver := or(receiver, mul(iszero(receiver), origin()))
        if and(iszero(token), gt(gasprice(), gasPrice)) {
          gasPrice := gasprice()
        }
        let totalGas := add(gasUsed, baseGas)
        if lt(totalGas, gasUsed) { revert(0x00, 0x00) }
        let payment := mul(totalGas, gasPrice)
        if xor(div(payment, gasPrice), totalGas) { revert(0x00, 0x00) }
        let success
        switch token
        case 0 {
          success := call(2300, receiver, payment, 
        }
        default {

        }
      }
      */

      function _changeThreshold(threshold) {
        if gt(threshold, sload(3)) { _error("GS201") }
        if iszero(threshold) { _error("GS202") }
        sstore(4, threshold)
        // event ChangedThreshold(uint256 threshold)
        mstore(0x00, threshold)
        log1(
          0x00, 0x20,
          0x610f7ff2b304ae8903c3de74c60c6ab1f7d6226b3f52c5161905bb5ad4039c93
        )
      }

      function _internalSetFallbackHandler(fallbackHandler) {
        if eq(fallbackHandler, address()) { _error("GS400") }
        // FALLBACK_HANDLER_STORAGE_SLOT
        sstore(
          0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5,
          fallbackHandler
        )
      }
    }
  }
}
