// TODO(nlordell):
// - Comment code
// - Don't use string literals where possible, they make the code bigger

// Preprocessor wishlist:
// - #define nonpayable() if callvalue() { _abort() }
// - #define EVENT_NAME 0x...
// - #define SENTINEL_MODULE 0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f
// - #define IS_L2_SAFE ...

object "Safe" {
  code {
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
        if callvalue() { _abort() }

        mstore(0x00, 0x20)
        mstore(0x3f, "\x0eSafe.yul 0.0.1")
        return(0x00, 0x60)
      }

      function setup() {
        // TODO(nlordell): only partially implemented
        sstore(0xcc69885fda6bcc1a4ace058b4a62bf5e179ea78fd58a1ccd71c22cc9b688792f, 1)
      }

      function enableModule() {
        _authorized()

        let module := shr(96, calldataload(0x10))
        if or(iszero(module), eq(module, 1)) { _error("GS101") }

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
        if or(iszero(module), eq(module, 1)) { _error("GS101") }

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

      function setFallbackHandler() {
        _authorized()

        let handler := shr(96, calldataload(0x10))
        _internalSetFallbackHandler(handler)
        // event ChangedFallbackHandler(address indexed handler)
        log2(
          0x00, 0x00,
          0x5ac6c46c93c8d0e53714ba3b53db3e7c046da994313d7ed0d192028bc7c228b0,
          handler
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
        mstore(0x00, callvalue())
        // event SafeReceived(address indexed sender, uint256 value)
        log2(
          0x00, 0x20,
          0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d,
          caller()
        )
        stop()
      }

      function fallback() {
        if callvalue() { _abort() }

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

      function _abort() {
        revert(0x00, 0x00)
      }

      function _error(code) {
        mstore(0x00, hex"08c379a0")
        mstore(0x04, 0x20)
        mstore(0x24, 0x05)
        mstore(0x44, code)
        revert(0x00, 0x64)
      }

      function _authorized() {
        if callvalue() { _abort() }
        if iszero(eq(caller(), address())) { _error("GS031") }
      }

      function _execTransactionFromModule() -> success {
        if callvalue() { _abort() }

        mstore(0x00, caller())
        mstore(0x20, 1)
        let slot := keccak256(0x00, 0x40)
        if or(eq(caller(), 1), iszero(sload(slot))) { _error("GS104") }

        success := _execute(
          calldataload(0x04),
          calldataload(0x24),
          add(calldataload(0x44), 0x04),
          calldataload(0x64),
          not(0)
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
        default { _abort() }
      }

      function _internalSetFallbackHandler(handler) {
        if eq(handler, address()) { _error("GS400") }
        // FALLBACK_HANDLER_STORAGE_SLOT
        sstore(
          0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5,
          handler
        )
      }
    }
  }
}
