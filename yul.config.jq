{
  language: "Yul",
  sources: {
    ($FILENAME): {
      content: $FILE,
    },
  },
  settings: {
    optimizer: {
      enabled: false,
    },
    outputSelection: {
      ("*"): {
        ("*"): [
          "evm.bytecode.object",
          "evm.deployedBytecode.object",
          "evm.deployedBytecode.opcodes",
          "evm.deployedBytecode.immutableReferences"
        ],
      },
    },
  },
}
