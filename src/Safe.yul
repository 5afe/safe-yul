object "Safe" {
  code {
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }

  object "runtime" {
    // thing
    code {
      mstore(0, 0x1337)
      return(0, 32)
    }
  }
}
