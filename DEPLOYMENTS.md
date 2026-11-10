# Deployments

Run on 10 Nov 2026 with the throwaway deployer `0x3E3B3480E0f538738aEfa759648511042Ac2bDf3`. No other wallet was used. The key is not in this file.

Origin and the reactive contract share one address because both were the deployer's nonce 0 on their own chain. They are different contracts on different networks.

The vault's final feed 1 state on Base Sepolia: entry `100000000000`, size `1000000`, open `false`, paused `true`, stopped `true`, epoch `4`, stop `270` bps, action arm, confidence `7721` bps. That is the crash close.

## lREACT

Sent **0.048 ETH** on Ethereum Sepolia to the Reactive faucet `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434` by calling `request(address)` with the deployer as the recipient.

- Faucet tx: [`0x03a327db4d1c811b31bd62e0fc2fd5ecc09b1febac2d770e2f2559fbeba2edbd`](https://sepolia.etherscan.io/tx/0x03a327db4d1c811b31bd62e0fc2fd5ecc09b1febac2d770e2f2559fbeba2edbd)
- Lasna balance after the tx: **5.04 lREACT** (`5040000000000000000` wei). The documented rate of 1 ETH → 100 lREACT predicts 4.8 lREACT for this payment. The balance that arrived was 5.04 lREACT.

The Sepolia ETH drip that funded the deployer, and the Base Sepolia drip, were sent before this run:

- Ethereum Sepolia funding: [`0xf65932fdd3b850e781bad1c7e79b071a4145204d61cf29fd3c83b1dda772738e`](https://sepolia.etherscan.io/tx/0xf65932fdd3b850e781bad1c7e79b071a4145204d61cf29fd3c83b1dda772738e)
- Base Sepolia funding: [`0x00ff0322103b8188b61349a1d71e8b9b0ea1b48657be57797ccb9038ebc0a508`](https://sepolia.basescan.org/tx/0x00ff0322103b8188b61349a1d71e8b9b0ea1b48657be57797ccb9038ebc0a508)

## Base Sepolia (chain id 84532)

Callback proxy: `0x476F44b11F5C942c58f4c8E3d0300E5710743585`.

`AEGIS_VAULT_FUND` was set to `0.00002ether` for this run. The script default of `0.0005ether` is larger than the 0.0001 ETH that was on the deployer.

| Item | Value |
| --- | --- |
| Deployer | [`0x3E3B3480E0f538738aEfa759648511042Ac2bDf3`](https://sepolia.basescan.org/address/0x3E3B3480E0f538738aEfa759648511042Ac2bDf3) |
| AegisOrigin | [`0x963E8F3a86745A86e72616D0f5809E47841BEA11`](https://sepolia.basescan.org/address/0x963E8F3a86745A86e72616D0f5809E47841BEA11) |
| AegisOrigin deploy tx | [`0x95a7799e6977247dff1cd6d6d2d311bbbb11136430a8712c9c83a040d07643a8`](https://sepolia.basescan.org/tx/0x95a7799e6977247dff1cd6d6d2d311bbbb11136430a8712c9c83a040d07643a8) |
| AegisVault | [`0x5FBb41e5C7e396b09a823B393d7EFA91E0702298`](https://sepolia.basescan.org/address/0x5FBb41e5C7e396b09a823B393d7EFA91E0702298) |
| AegisVault deploy tx | [`0xdccddd9061653432dd8398ca47f59a95ac711b6c3cd8c75ef7e9455e4a57771b`](https://sepolia.basescan.org/tx/0xdccddd9061653432dd8398ca47f59a95ac711b6c3cd8c75ef7e9455e4a57771b) |
| Vault funding tx (0.00002 ETH) | [`0x3315c46f095ac9744d99075aba7ca8a4642b32356e44e055fb6a4fbf590c97d1`](https://sepolia.basescan.org/tx/0x3315c46f095ac9744d99075aba7ca8a4642b32356e44e055fb6a4fbf590c97d1) |
| `openPosition` on the vault | [`0x77c1a3ebc2c96863a68e86b22ff9a93f398b58bd769e73876b92705c05500556`](https://sepolia.basescan.org/tx/0x77c1a3ebc2c96863a68e86b22ff9a93f398b58bd769e73876b92705c05500556) |
| `openPosition` on the origin | [`0xad2002d3989a116ca023e062749e30fd463bcdf75419e2de324d9002fd72fc66`](https://sepolia.basescan.org/tx/0xad2002d3989a116ca023e062749e30fd463bcdf75419e2de324d9002fd72fc66) |
| Calm `postPolicy` (arm, 911 bps) | [`0x16faa162875ab0e03eca5816ec44f00f269dbce738c8f668c651790b299e71d4`](https://sepolia.basescan.org/tx/0x16faa162875ab0e03eca5816ec44f00f269dbce738c8f668c651790b299e71d4) |
| Flat `pushPrice` | [`0x2070900db9bc039f4f4f985558f12edf940362eeb081e8b5142279e6701d7ddf`](https://sepolia.basescan.org/tx/0x2070900db9bc039f4f4f985558f12edf940362eeb081e8b5142279e6701d7ddf) |
| Wick `postPolicy` (hold, 2557 bps confidence) | [`0xd1a3466a4ccf19cca2abf7c1ca800e51d793c144e63601f7db246b82a48efd3b`](https://sepolia.basescan.org/tx/0xd1a3466a4ccf19cca2abf7c1ca800e51d793c144e63601f7db246b82a48efd3b) |
| Grind `postPolicy` (pause, 432 bps) | [`0xd6c2e6aab9508a0a4f2b4599bce85144f639b313dc8b21bcaf8261e14a1f12ea`](https://sepolia.basescan.org/tx/0xd6c2e6aab9508a0a4f2b4599bce85144f639b313dc8b21bcaf8261e14a1f12ea) |
| Grind `pushPrice` | [`0x384e486ee97bfbbe6f35ffba072a105ec89a7121352034f197f03247df582e3a`](https://sepolia.basescan.org/tx/0x384e486ee97bfbbe6f35ffba072a105ec89a7121352034f197f03247df582e3a) |
| Crash `postPolicy` (arm, 270 bps) | [`0xc3e3e6926a911e7c52dc13a08ba4d71807e6cf4535d4e03660b940acbb5b7fc7`](https://sepolia.basescan.org/tx/0xc3e3e6926a911e7c52dc13a08ba4d71807e6cf4535d4e03660b940acbb5b7fc7) |
| Crash `pushPrice` | [`0x3ee6064a848d7b12509f04e03c118e5a5f2c2f0e5ebaa067e9d26c806e9d7f51`](https://sepolia.basescan.org/tx/0x3ee6064a848d7b12509f04e03c118e5a5f2c2f0e5ebaa067e9d26c806e9d7f51) |
| Callback, calm `syncPolicy` | [`0x4808668166aec17886587579874cc774ed09938e7617c20ae5214a30a91de36e`](https://sepolia.basescan.org/tx/0x4808668166aec17886587579874cc774ed09938e7617c20ae5214a30a91de36e) |
| Callback, grind `syncPolicy` | [`0x590b63e656c7f8f9c999e756aaa8fd68ad35fb38a2fd3a6f06f8d3993836c997`](https://sepolia.basescan.org/tx/0x590b63e656c7f8f9c999e756aaa8fd68ad35fb38a2fd3a6f06f8d3993836c997) |
| Callback, grind pause | [`0x75d6d8a0eeccae1ffb1fb8e0e6ef068530284ffa5bfaeae592ea17be914d76ec`](https://sepolia.basescan.org/tx/0x75d6d8a0eeccae1ffb1fb8e0e6ef068530284ffa5bfaeae592ea17be914d76ec) |
| Callback, crash `syncPolicy` | [`0x162c0d1d402f985ce109418e9559cf5b520ccd746459ec004bd152176f667ead`](https://sepolia.basescan.org/tx/0x162c0d1d402f985ce109418e9559cf5b520ccd746459ec004bd152176f667ead) |
| Callback, crash stop | [`0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c`](https://sepolia.basescan.org/tx/0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c) |

The crash-stop callback is sent to the callback proxy. Its calldata names the vault `0x5FBb…2298` and carries the reactive address `0x963E…EA11` in the first argument of `protect`. There is no separate callback for the wick: Lasna rejected that policy. There is no callback for the flat price: the drawdown was 0.

The flat-price refusal shown in the Anvil demo (`ConditionsNotMet`) was not repeated on Base Sepolia. That check remains a local test.

## Lasna (chain id 5318007)

System contract: `0x8888888888888888888888888888888888888888`.

The reactive deploy attached 1 lREACT. After the loop the contract balance was `883092700000000000` wei, so the `react` calls drew on that balance.

| Item | Value |
| --- | --- |
| AegisReactive | [`0x963E8F3a86745A86e72616D0f5809E47841BEA11`](https://lasna.reactscan.net/address/0x963E8F3a86745A86e72616D0f5809E47841BEA11) |
| AegisReactive deploy tx | [`0xa22083593707bf3c88e30e2c2e158795a7660afbaa018dda9db44767b2aa1b65`](https://lasna.reactscan.net/tx/0xa22083593707bf3c88e30e2c2e158795a7660afbaa018dda9db44767b2aa1b65) |
| `setVault` tx | [`0x25b7089b432529a3359abb87fcef2009b76b21195179ce28db82df81e614f453`](https://lasna.reactscan.net/tx/0x25b7089b432529a3359abb87fcef2009b76b21195179ce28db82df81e614f453) |
| `react` for the origin position | [`0x4c2d959ee8b2f96679caccb216d742a40294910fbe0ecee25d38e771287bcf49`](https://lasna.reactscan.net/tx/0x4c2d959ee8b2f96679caccb216d742a40294910fbe0ecee25d38e771287bcf49) |
| `react` for the calm policy | [`0xbb5338441e0e86322515628465282fb652b42bc8446a46d072af4b5a45defdbe`](https://lasna.reactscan.net/tx/0xbb5338441e0e86322515628465282fb652b42bc8446a46d072af4b5a45defdbe) |
| `react` for the flat price | [`0xcbcef99d28132dd5ff5ffc36e5da078013b5a05b319015966bae155cf7b40b44`](https://lasna.reactscan.net/tx/0xcbcef99d28132dd5ff5ffc36e5da078013b5a05b319015966bae155cf7b40b44) |
| `react` for the wick policy (rejected) | [`0x83d1a9a759fbd7dd8fbd450adeb551dac55beeedb10a0e2c670f0a08096404f4`](https://lasna.reactscan.net/tx/0x83d1a9a759fbd7dd8fbd450adeb551dac55beeedb10a0e2c670f0a08096404f4) |
| `react` for the grind policy | [`0xad4391ec3d3bd61d175b08226bed3d9dd9474d2d41ef55b7a49e969ac6037147`](https://lasna.reactscan.net/tx/0xad4391ec3d3bd61d175b08226bed3d9dd9474d2d41ef55b7a49e969ac6037147) |
| `react` for the grind price (pause requested) | [`0x426875ae23770125889904c899fcda0559a45eb754f2b52ccf6746cd182ffcc5`](https://lasna.reactscan.net/tx/0x426875ae23770125889904c899fcda0559a45eb754f2b52ccf6746cd182ffcc5) |
| `react` for the crash policy | [`0x47b7f2d0643855f1be7ce990a96f7ac6efd5ad72a8bd8ebbe7e8732f94791489`](https://lasna.reactscan.net/tx/0x47b7f2d0643855f1be7ce990a96f7ac6efd5ad72a8bd8ebbe7e8732f94791489) |
| `react` for the crash price (stop requested) | [`0x09950b9198f059bb14ac1b588b188b1e0c2fab88c21286e1966f8f711e1d2c27`](https://lasna.reactscan.net/tx/0x09950b9198f059bb14ac1b588b188b1e0c2fab88c21286e1966f8f711e1d2c27) |
