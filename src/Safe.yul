// TODO(nlordell):
// - Comment code
// - Don't use string literals where possible, they make the code bigger

// Preprocessor wishlist:
// - #define nonpayable() if callvalue() { _abort() }
// - #define EVENT_NAME 0x...

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
      case 0xf08a0323 { setFallbackHandler() }
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

      function setFallbackHandler() {
        _authorized()

        let handler := shr(96, calldataload(0x10))
        _internalSetFallbackHandler(handler)
        log2(
          0x00, 0x00,
          // event ChangedFallbackHandler(address indexed handler)
          0x5ac6c46c93c8d0e53714ba3b53db3e7c046da994313d7ed0d192028bc7c228b0,
          handler
        )
        stop()
      }

      function simulateAndRevert() {
        if callvalue() { _abort() }

        let callData := add(0x04, calldataload(0x24))
        let callDataLength := calldataload(callData)
        calldatacopy(0x00, add(callData, 0x20), callDataLength)
        mstore(
          0x00,
          delegatecall(
            gas(),
            calldataload(0x04),
            0x00, callDataLength,
            0x00, 0x00
          )
        )
        mstore(0x20, returndatasize())
        returndatacopy(0x40, 0x00, returndatasize())
        revert(0x00, add(returndatasize(), 0x40))
      }

      function receive() {
        mstore(0x00, callvalue())
        log2(
          0x00, 0x20,
          // event SafeReceived(address indexed sender, uint256 value)
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
        if iszero(eq(caller(), address())) { _error("GS031") }
      }

      function _internalSetFallbackHandler(handler) {
        if eq(handler, address()) { _error("GS400") }
        sstore(
          // FALLBACK_HANDLER_STORAGE_SLOT
          0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5,
          handler
        )
      }
    }
  }
}
