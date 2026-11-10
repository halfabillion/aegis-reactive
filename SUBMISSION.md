# Aegis — DoraHacks BUIDL draft

Prepared for DoraHacks. The testnet loop has been run. The public repository and judging demo are in this repo.

## Name

Aegis

## Tagline

A neural net sets the stop. Reactive fires it only when the price agrees.

## Track

Reactive Meets AI

## Description

Aegis guards a mock position with a stop that moves. A fixed-point neural net reads a short price window and publishes a policy: a stop width in basis points, an action of hold, arm, or pause, and a confidence score. That policy is an event on an origin contract. A reactive contract stores the position's entry and the latest accepted policy. On each price event it requests a destination callback only when the drawdown meets the policy. The vault on the destination chain repeats the arithmetic from its own entry and refuses the call when the price has not fallen far enough. Pause freezes the position. Arm closes it.

`forge test` passes 23 tests, including one 256-run fuzz. The scorer's 9 unit tests pass. `./demo/demo.sh` runs the same windows on Anvil. On 10 Nov 2026 those windows were also posted from Base Sepolia. Lasna `react` stored the crash policy at 270 bps, and the Base Sepolia callback [`0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c`](https://sepolia.basescan.org/tx/0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c) left the vault stopped. The grind callback paused it first. The full hash list is in `DEPLOYMENTS.md`.

## How it uses Reactive

`AegisReactive` inherits `AbstractReactive` from reactive-lib-omni v0.1.0. The constructor calls `SYSTEM.subscribe` three times on the origin contract, for `PositionOpened`, `PriceUpdated`, and `PolicyPosted`, with `REACTIVE_IGNORE` on the other topics. `react` is `onlySystem`. A confident, newer policy is clamped to 100–2000 bps and synced with `SYSTEM.requestCallbackV_1_0`. A price requests `protect` with gas limit `1_000_000` and `address(0)` in the first argument, which is the placeholder the network replaces. The destination vault inherits `AbstractCallback` and guards `syncPolicy` and `protect` with `onlyServiceProvider` and `onlyCallbackSender`.

The deployed origin and vault are on Base Sepolia. The reactive contract is on Lasna. The local demo still etches a mock system contract at `0x8888…8888` and uses `CallbackRelay` so the Anvil run does not need those networks. The live crash callback was sent to the Base Sepolia callback proxy `0x476F44b11F5C942c58f4c8E3d0300E5710743585`, and the calldata carries the reactive address as the first `protect` argument.

## How the model runs inside the system

`scorer/aegis_scorer.py` is a 5×4×3 network. Hidden units use ReLU. Outputs use a rational sigmoid. Weights are integers in `scorer/weights.json`, hand-set so three fixtures separate: a quiet book stays armed, a three-step 1% grind pauses, and a seven-step 3% crash closes. They were not fit on market data. The demo calls `score()` and posts the result with `postPolicy`. The reactive contract rejects confidence below 5500 bps, which is why the recovered wick does not replace the armed stop. `scorer/llm_hook.py` can POST a summary only when a caller passes `enabled=True` and a URL. The demo and the unit tests leave it off.

## Tech stack

Solidity 0.8.29, Foundry, reactive-lib-omni v0.1.0, Python 3 standard library, Anvil for the local demo. Designed for Lasna chain id 5318007 and Base Sepolia chain id 84532.

## Links

| Field | Value |
| --- | --- |
| Public repository | https://github.com/halfabillion/aegis-reactive |
| Base Sepolia origin | [`0x963E8F3a86745A86e72616D0f5809E47841BEA11`](https://sepolia.basescan.org/address/0x963E8F3a86745A86e72616D0f5809E47841BEA11) |
| Base Sepolia vault | [`0x5FBb41e5C7e396b09a823B393d7EFA91E0702298`](https://sepolia.basescan.org/address/0x5FBb41e5C7e396b09a823B393d7EFA91E0702298) |
| Lasna reactive contract | [`0x963E8F3a86745A86e72616D0f5809E47841BEA11`](https://lasna.reactscan.net/address/0x963E8F3a86745A86e72616D0f5809E47841BEA11) |
| Origin event, crash `pushPrice` | [`0x3ee6064a848d7b12509f04e03c118e5a5f2c2f0e5ebaa067e9d26c806e9d7f51`](https://sepolia.basescan.org/tx/0x3ee6064a848d7b12509f04e03c118e5a5f2c2f0e5ebaa067e9d26c806e9d7f51) |
| Lasna `react` for that price | [`0x09950b9198f059bb14ac1b588b188b1e0c2fab88c21286e1966f8f711e1d2c27`](https://lasna.reactscan.net/tx/0x09950b9198f059bb14ac1b588b188b1e0c2fab88c21286e1966f8f711e1d2c27) |
| Base Sepolia stop callback | [`0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c`](https://sepolia.basescan.org/tx/0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c) |
| Demo video | [`video/aegis-demo.mp4`](video/aegis-demo.mp4), 93 seconds, 1920×1080, voice-over and captions. |

## Team

Ali Ghaedi, solo. GitHub: halfabillion.

## Form fields not confirmed

The DoraHacks event page returned HTTP 405 when it was fetched, so extra BUIDL boxes were not visible. Leave any unseen field blank rather than inventing an answer. Rules that were read are in `RULES.md`.
