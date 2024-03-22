{
  language: (if $FILENAME | endswith(".yul")
    then "Yul"
    else "Solidity"
  end),
  sources: {
    ($FILENAME): {
      content: $FILE
    }
  },
  settings: {
    optimizer: {
      enabled: false
    },
    outputSelection: {
      ("*"): {
        ("*"): [
          "abi",
          "evm.bytecode.object",
          "evm.deployedBytecode.object",
          "evm.deployedBytecode.opcodes",
          "evm.deployedBytecode.immutableReferences"
        ]
      }
    }
  }
}
