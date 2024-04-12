# Safe Smart Accout Implemented in Yul

## Functional Differences

While this implementation strives to be a pure port, there are a couple
functional differences with the reference implementation:

- Some view methods are implemented in the fallback handler using simulation
  techniques (`simulateAndRevert`) instead of in the account itself.
- Calldata length is not verified in function calls. This is a difference with
  the Solidity ABI in general, but not a security issue for the account, but may
  be unexpected if callers make certain (unsafe) assumptions about how contracts
  react to incorrectly ABI-encoded calls.
- When the fallback handler is address `0`, we still call it. The output will be
  the same, but will do an extra unnecessary `CALL`. However, the extra code and
  gas for checking the handler address is non-zero is not worth it as Safes are
  almost never configured this way in practice, and when they are, shouldn't be
  called this way anyway.
- `getModules` reverts if there are more than the default page size of modules.
- `simulateAndRevert` is payable. It reverts so funds can't be lost.
- We always revert with `GS204` on duplicate owners during `setup`. This is
  ensured by reversing the order in which we build the linked list.
- `setup` function is `payable`.

## Benchmarks

|                  | Configuration  | EOA   | Yul    | 1.4.1  | 1.5.0  | Gas Improvement | Overhead Improvement |
| ---------------- | -------------- | ----- | ------ | ------ | ------ | --------------- | -------------------- |
| Setup            | 1 of 1         | 0     | 163848 | 166349 | 166309 | 1.50%           | 1.50%                |
|                  | 1 of 1 + guard | -     | 163848 | 166349 | 166309 | 1.50%           | 1.50%                |
|                  | 2 of 2         | -     | 186756 | 189813 | 189755 | 1.61%           | 1.61%                |
|                  | 3 of 3         | -     | 209652 | 213265 | 213189 | 1.69%           | 1.69%                |
|                  | 3 of 5         | -     | 255468 | 260193 | 260081 | 1.82%           | 1.82%                |
| Ether Transfer   | 1 of 1         | 21000 | 55807  | 58718  | 58706  | 4.96%           | 7.72%                |
|                  | 1 of 1 + guard | -     | 60558  | 64502  | 64535  | 6.11%           | 9.07%                |
|                  | 2 of 2         | -     | 62358  | 65796  | 65750  | 5.23%           | 7.67%                |
|                  | 3 of 3         | -     | 68897  | 72862  | 72819  | 5.44%           | 7.65%                |
|                  | 3 of 5         | -     | 68909  | 72850  | 72819  | 5.41%           | 7.60%                |
| ERC20 Transfer   | 1 of 1         | 51800 | 80049  | 82975  | 82975  | 3.53%           | 9.39%                |
|                  | 1 of 1 + guard | -     | 84845  | 88769  | 88825  | 4.42%           | 10.61%               |
|                  | 2 of 2         | -     | 86612  | 90029  | 90019  | 3.80%           | 8.94%                |
|                  | 3 of 3         | -     | 93164  | 97109  | 97089  | 4.06%           | 8.71%                |
|                  | 3 of 5         | -     | 93164  | 97097  | 97065  | 4.05%           | 8.68%                |
| ERC1155 Transfer | 1 of 1         | 53707 | 82041  | 84967  | 84967  | 3.44%           | 9.36%                |
|                  | 1 of 1 + guard | -     | 86874  | 90810  | 90842  | 4.33%           | 10.61%               |
|                  | 2 of 2         | -     | 88580  | 92034  | 92024  | 3.75%           | 9.01%                |
|                  | 3 of 3         | -     | 95143  | 99088  | 99068  | 3.98%           | 8.69%                |
|                  | 3 of 5         | -     | 95143  | 99100  | 99080  | 3.99%           | 8.72%                |
