# Safe Smart Accout Implemented in Yul

## Progress

- [ ] Safe,
- [x] Singleton,
- [x] NativeCurrencyPaymentFallback,
- [ ] ModuleManager,
- [ ] OwnerManager,
- [ ] SignatureDecoder,
- [ ] SecuredTokenTransfer,
- [x] ISignatureValidatorConstants,
- [x] FallbackManager,
- [ ] StorageAccessible,
- [ ] GuardManager

## Functional Differences

While this implementation strives to be a pure port, there are a couple
functional differences with the reference implementation:

- Calldata length is not verified in function calls. This is a difference with
  the Solidity ABI in general, but not a security issue for the account, but may
  be unexpected if callers make certain (unsafe) assumptions about how contracts
  react to incorrectly ABI-encoded calls.
- When the fallback handler is address `0`, we still call it. The output will be
  the same, but will do an extra unnecessary `CALL`. However, the extra code and
  gas for checking the handler address is non-zero is not worth it as Safes are
  almost never configured this way in practice, and when they are, shouldn't be
  called this way anyway.
