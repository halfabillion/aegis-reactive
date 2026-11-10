# Gas estimate

Read-only, 10 Nov 2026. No transaction was broadcast. The deployer `0x3E3B3480E0f538738aEfa759648511042Ac2bDf3` had **0.0001 ETH** on Base Sepolia, **0.05 ETH** on Ethereum Sepolia, and **0** on Lasna.

`eth_gasPrice` was **6,000,000 wei** (0.006 gwei) on `https://sepolia.base.org` and **100 gwei** on `https://lasna-rpc.rnk.dev/`. Gas units come from `forge script` simulations of the deploy and trigger calls, run against those RPCs **without** `--broadcast`. On Lasna the eight `react()` figures are `gasleft()` around the call itself, so they do not include the outer transaction overhead.

## Base Sepolia

| Transaction | Gas | ETH at 0.006 gwei |
| --- | ---: | ---: |
| Deploy `AegisOrigin` | 463,775 | 0.000002782650 |
| Deploy `AegisVault` | 1,152,768 | 0.000006916608 |
| `vault.openPosition` | 134,916 | 0.000000809496 |
| `origin.openPosition` | 96,717 | 0.000000580302 |
| `postPolicy` calm | 68,448 | 0.000000410688 |
| `pushPrice` flat | 73,321 | 0.000000439926 |
| `postPolicy` wick | 44,812 | 0.000000268872 |
| `postPolicy` grind | 44,829 | 0.000000268974 |
| `pushPrice` grind | 45,851 | 0.000000275106 |
| `postPolicy` crash | 44,829 | 0.000000268974 |
| `pushPrice` crash | 45,851 | 0.000000275106 |
| **All of the above** | **2,216,117** | **0.000013296702** |

Vault deploy plus the nine trigger calls, without the origin deploy, is **1,752,342 gas** and **0.000010514052 ETH**.

**0.0001 ETH covers this.** About **0.0000867 ETH** remains after the full table. Forge's own max-fee quote for the same gas was 0.010000001 gwei, which is **0.000022161 ETH**, and that still fits in 0.0001 ETH.

The Base L1 fee oracle (`0x4200…000F`) reported `l1BaseFee` of 19 wei. A `getL1Fee` sample returned 101 wei. That does not change the result.

The 0.0005 ETH vault prefund in `script/deploy_testnet.sh` does **not** fit in 0.0001 ETH. Callback execution was not part of the 2,216,117 gas. At this gas price a few hundred thousand gas of callback work is a few millionths of an ETH, so the leftover 0.0000867 ETH can fund the vault for those callbacks. Do not send 0.0005 ETH.

## Lasna

| Transaction | Gas | lREACT at 100 gwei |
| --- | ---: | ---: |
| Deploy `AegisReactive` (constructor calls `subscribe` three times) | 1,569,388 | 0.1569388 |
| `setVault` | 65,477 | 0.0065477 |
| **Deployer pays** | **1,634,865** | **0.1634865** |

`react()` in-call gas for the same eight origin events: 116,798, 84,909, 42,907, 33,998, 67,889, 70,027, 67,896, 69,867. Sum **554,291 gas**, **0.0554291 lREACT** at 100 gwei, before outer-transaction overhead.

Forge reported a 200 gwei max fee on Lasna, which prices the deployer transactions at **0.326973 lREACT**.

**Minimum to be safe: 1 lREACT.** Put at least **0.4 lREACT** on the deployer (deploy and `setVault`, with room for the 200 gwei max fee) and **0.2 lREACT** on the reactive contract (the eight `react()` calls, with room for transaction overhead and a fee above `gas * gasPrice`). 1 lREACT covers both. At the documented rate that is **0.01 ETH** sent to a Reactive faucet. The 0.0001 Base Sepolia ETH balance cannot buy that.

## Faucets

Docs, https://dev.reactive.network/reactive-mainnet: **1 ETH sent → 100 lREACT**. Do not send more than **5 ETH** in one transaction; the docs say the excess is lost and pays no extra lREACT.

Neither faucet stores that rate. `rate()`, `exchangeRate()`, and `RATIO()` revert on both. The on-chain gate is `max_payout()` and a zero-value revert.

| | Ethereum Sepolia `0x9b9B…f434` | Base Sepolia `0x2afa…967` |
| --- | ---: | ---: |
| `max_payout()` | 50 ETH | 1 ETH |
| `eth_call` with value 0 | reverts `Just no` | reverts `Just no` |
| `eth_call` with 1 wei | succeeds | succeeds |
| `eth_call` above `max_payout` | 51 ETH succeeds | 1.1 ETH and 5 ETH succeed |

The on-chain minimum is **1 wei**. There is no larger minimum in these calls. On the Sepolia faucet bytecode, a deposit above `max_payout` is still accepted, and the `PaymentRequest` amount is capped at `max_payout`. The Base faucet was not disassembled to that instruction; its calls simply do not revert above `max_payout`. The docs' 5 ETH warning is stricter than the Base `max_payout` of 1 ETH and looser than the Sepolia `max_payout` of 50 ETH. A 0.01 ETH faucet payment, for 1 lREACT at the documented rate, is under both caps and under the 5 ETH warning.

The same deployer address currently holds **0.05 ETH** on Ethereum Sepolia. That is enough for one Sepolia faucet payment in the 1 wei–5 ETH range. This estimate did not send it.
