object "Safe" {
  code {
    let size := datasize("runtime")
    datacopy(0, dataoffset("runtime"), size)
    return(0, size)
  }

  object "runtime" {
    code {
      switch shr(224, calldataload(0))
      case 0xffa1ad74 { VERSION() }
      default { _abort() }

      function VERSION() {
        if callvalue() { _abort() }

        mstore(0x00, 0x20)
        mstore(0x3f, "\x0eSafe.yul 0.0.1")
        return(0x00, 0x60)
      }

      function _abort() {
        revert(0x00, 0x00)
      }
    }
  }
}
