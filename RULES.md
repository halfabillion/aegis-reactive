# Reactive Omni Buildathon — rules this repo was checked against

Checked on 10 November 2026. Nothing in this file is inferred as a rule unless a source says it. Items that could not be read are listed under [Unconfirmed](#unconfirmed).

Entrant: Ali Ghaedi, solo, GitHub `halfabillion`. Track chosen for this repo: **Reactive Meets AI**.

## Sources

| Source | URL | What was retrieved |
| --- | --- | --- |
| Reactive blog post, 4 Nov 2026 | https://blog.reactive.network/reactive-omni-buildathon-thirty-days-to-find-out-what-one-second-buys/ | Full article text |
| DoraHacks event page | https://dorahacks.io/hackathon/reactive-omni-buildathon | Search-index snippet only. A direct fetch returned HTTP 405 |
| Getting started (Omni vs legacy) | https://dev.reactive.network/ | Full page |
| Reactive contracts | https://dev.reactive.network/reactive-contracts | Full page |
| Callback contracts | https://dev.reactive.network/callback-contracts | Full page |
| Origins and destinations | https://dev.reactive.network/origins-and-destinations | Full page |
| Reactive Mainnet / Lasna | https://dev.reactive.network/reactive-mainnet | Full page |
| Legacy mainnet page | https://dev.reactive.network/legacy/reactive-mainnet | Search snippet only. It still documents the old system-contract address |
| Remix tutorial | https://dev.reactive.network/education/use-cases/remix-ide-demo | Search snippet. It still documents the pre-Omni deploy path |
| `rnk_*` RPC methods | https://dev.reactive.network/rnk-rpc-methods | Search snippet |
| Omni library | https://github.com/Reactive-Network/reactive-lib-omni | Tree and Solidity sources at tag `v0.1.0`, commit `3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8` |
| Older demo repo | https://github.com/Reactive-Network/reactive-smart-contract-demos | Search snippets of `BasicDemoReactiveContract.sol`. That code is the legacy `vm` / `emit Callback` style |
| Older library | https://github.com/Reactive-Network/reactive-lib | `IReactive.sol` on `main` still uses the legacy `LogRecord` field names and `Callback` event |

## Confirmed event facts

From the blog:

- Reactive Omni has been live on mainnet since 28 October 2026.
- The buildathon opens 5 November 2026 and runs until 5 December 2026.
- Prize pool is **$5,500**, denominated in USD and **paid in REACT**. It is not described as 5,500 REACT tokens.
- Registration and submissions run through DoraHacks.
- Omni uses CometBFT, with about 1 second blocks and instant finality. The previous network was about 7 second blocks.

From the DoraHacks search snippet, not from a rendered page:

- Prize pool displayed as `5,500 USD`.
- Pre-registration `2026/11/04 12:00`.
- Submission `2026/11/05 12:00`.
- Deadline `2026/12/05 20:00`. The snippet does not name the timezone. The page chrome in the snippet says the timeline is UTC, so 20:00 UTC is the reading of that snippet, not of a rendered page.
- Tags: `GitHub/Gitlab/Bitbucket Link Required`, `Demo Video Required`.
- The same snippet said "Submission starts in 9 hours". That relative line disagrees with the absolute dates and with the 4 November blog, so it is not treated as a fact.

## Tracks

Confirmed from the blog.

### Every Second Counts

Time-sensitive DeFi on Unichain Sepolia, Base Sepolia, or both, with Lasna in the middle. Unichain Sepolia has 1 second blocks. Base Sepolia, since the Denim upgrade, has 200 ms blocks. The blog asks for latency across the full loop. This track **runs on Lasna testnet**.

Prizes: $2,000 first, $250 runner-up.

### Set It and Forget It

Personal automations on any chain Reactive supports. Usefulness matters more than speed. Projects whose AI only helped write the code belong here, not in Reactive Meets AI.

Prizes: $2,000 first, $250 runner-up.

### Reactive Meets AI

The blog's wording:

> This track is deliberately open. Bring a neural network into the loop and show us how it works alongside Reactive. A model could decide what a reactive contract does next, interpret the events it picks up, or be triggered by them.
>
> There's one rule: the AI has to be part of the running system, not just the tool you used to write the code. Projects where AI only helped you build belong in Set It and Forget It.

Prize: **$1,000 for first place**. No runner-up is listed for this track.

This track may use **Reactive mainnet or Lasna**. That is the blog's ground rule for the two tracks that are not Every Second Counts.

## Judging

Confirmed from the blog. Every entry is scored from 1 to 5 on four equally weighted criteria:

1. **Execution.** Does it run? They want the reactive transactions and the callbacks they trigger on-chain. Entries without them are not scored further.
2. **Integration.** Does the reactive contract do real work, or is it bolted on?
3. **Usefulness.** Does it solve a problem real users have?
4. **Craft.** Readable code, a working demo, and documentation someone else could follow.

Judges: the Reactive team. Guest judges, if any, will be announced on the DoraHacks page. None could be confirmed, because that page returned HTTP 405.

## Submission requirements

Confirmed from the blog. A submission includes:

- a link to a public repository
- deployed contract addresses
- a few transaction hashes showing the full loop from the origin event to the callback
- a demo video under three minutes

Ground rules from the blog:

- Repositories must be public and open-source by submission time.
- The submission itself must be built during the event. Prior work may be a dependency, not the submission.
- On Base Sepolia, timers, cooldowns, and deadlines must use timestamps rather than block counts, because blocks arrive about every 200 ms.

The DoraHacks snippet repeats that a Git host link and a demo video are required. It does not add fields beyond that in the text that was visible.

## Reactive contract model this repo targets

Confirmed from the current Omni docs and from `reactive-lib-omni` v0.1.0. New contracts use this shape, not the legacy RVM shape.

- A reactive contract is an ordinary Solidity contract. There is no separate ReactVM copy and no `vm` flag.
- Inherit `AbstractReactive`. It sets `SYSTEM` to `0x8888888888888888888888888888888888888888`, defines `REACTIVE_IGNORE` as `0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad`, and exposes `onlySystem`.
- `onlySystem` checks `msg.sender` against that system contract and reverts with `NotAuthorized` otherwise.
- Subscribe with `SYSTEM.subscribe(chainId, contract, topic0, topic1, topic2, topic3)`. `chainId` `0` matches any chain. `address(0)` matches any contract. `REACTIVE_IGNORE` matches any topic. At least one criterion must be specific. Criteria are equality only. One subscription cannot express `OR`; call `subscribe` again. Subscriptions are not readable back from contract storage.
- `react(LogRecord calldata log)` is called by the system contract. `LogRecord` fields are `chainId`, `contractAddress`, `topic0`–`topic3`, `data`, `blockNumber`, `opCode`, `blockHash`, `txHash`, `logIndex`. `opCode` is the number of topics in the original log. `data` is the ABI encoding of the non-indexed parameters. Reverting inside `react` is caught, billed, and surfaced as `ReactiveContractReverted`, so a filter should return rather than revert.
- To act on another chain, call `SYSTEM.requestCallbackV_1_0` with `CallbackConfiguration_V_1_0 { chainId, recipient, gasLimit, payload }`. Emitting `Callback` still works and is deprecated.
- The payload's first argument must be an `address`, passed as `address(0)`. The network replaces it with the reactive contract's address so the destination can authenticate the caller.
- The docs also say the network "replaces the first 160 bits of the payload". Taken literally, that would overwrite the 4-byte selector. The callback-contract page says the first Solidity argument is that address and that `onlyCallbackSender` checks it. This repo's local relay overwrites the first ABI word after the selector. That matches the callback API. It has **not** been checked against a live Lasna transaction.
- Destination contracts inherit `AbstractCallback(callbackProxy, callbackSender)`. Callback methods use both `onlyServiceProvider` (caller is the chain's callback proxy) and `onlyCallbackSender` (injected address is the reactive contract).
- Callbacks are billed to the **recipient**, in the destination chain's native token, not in REACT. A recipient in debt receives nothing. A failed callback is still charged. The reactive contract pays for reactive transactions in REACT and must be funded.
- Deploy the reactive contract first, then the callback contract with that address, then set the recipient on the reactive contract. `_CALLBACK_SENDER` is immutable.
- A contract cannot inherit both `AbstractReactive` and `AbstractCallback`.
- Solidity in the docs and the library is `^0.8.29`.

### Chains used in the deployment notes

From https://dev.reactive.network/origins-and-destinations. Mainnets and testnets must not be mixed.

| Chain | Role in the docs | Chain id | Callback proxy |
| --- | --- | --- | --- |
| Reactive Lasna | origin and destination | 5318007 | `0x8888888888888888888888888888888888888888` |
| Base Sepolia | origin and destination | 84532 | `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Ethereum Sepolia | origin and destination | 11155111 | `0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4` |
| Unichain Sepolia | origin and destination | 1301 | `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |
| Reactive mainnet | origin and destination | 1597 | `0x8888888888888888888888888888888888888888` |

Lasna, from https://dev.reactive.network/reactive-mainnet:

- RPC `https://lasna-rpc.rnk.dev/`
- Chain id `5318007`
- Symbol `lREACT`
- Explorer `https://lasna.reactscan.net/`
- System contract, shared with Reactive mainnet: `0x8888888888888888888888888888888888888888`

Testnet lREACT faucet, same page:

- Ethereum Sepolia faucet `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- Base Sepolia faucet `0x2afaFD298b23b62760711756088F75B7409f5967`
- Rate: 1 ETH sent → 100 lREACT. Do not send more than 5 ETH in one transaction. Above that, the excess is lost and no extra lREACT is minted. Maximum shown: 5 ETH → 500 lREACT.
- A terminal path calls `request(address)` on those contracts with a value such as `0.1 ether`.

This repo does not call the faucet and does not send ETH.

The legacy page https://dev.reactive.network/legacy/reactive-mainnet still shows system contract `0x0000000000000000000000000000000000fffFfF`. The current Omni pages and `AbstractReactive` use `0x8888…8888`. New code in this repo uses `0x8888…8888`. The legacy address is still the documented emitter of `Cron` events. This repo does not subscribe to cron.

The Remix tutorial still shows the old service address and a `vm`-style deploy. It was not used as the template.

`https://dev.reactive.network/rnk-rpc-methods` documents `rnk_getFilters` and related calls. The Omni getting-started page says the custom RVM RPC methods are gone. Whether `rnk_*` still answers on Lasna was not checked. This repo does not call those methods.

## Unconfirmed

- The full DoraHacks page body, including any extra BUIDL form fields, eligibility rules, code of conduct, or IP terms. Direct fetch returned HTTP 405.
- Whether the deadline clock `2026/12/05 20:00` is UTC. That is how the search snippet's timeline is labeled. The blog only says "until December 5th".
- Guest judges. The blog says they would be announced on DoraHacks. The page could not be rendered.
- A required AI-disclosure field. The blog requires the model to be inside the running system. It does not ask for a separate disclosure form. This repo includes a voluntary disclosure in `README.md` anyway.
- Team size, KYC, or country limits. Not found in the sources that loaded.
- The exact byte offset of the live callback address injection, as noted above.
- A measured gas budget for these contracts on Lasna or Base Sepolia. Nothing was deployed.
- Whether the published `reactive-smart-contract-demos` repository has an Omni branch that was not returned by search. The `main` snippets that were retrieved are legacy.

## What this repository does with those rules

- The running system includes a fixed-point neural net. The coding assistant that helped write the repo is not the entry.
- Contracts use `reactive-lib-omni` v0.1.0: `subscribe`, `react` with `onlySystem`, and `requestCallbackV_1_0`.
- `forge test` simulates that loop with a mock system contract. It does **not** produce the on-chain reactive transactions and destination callbacks the Execution criterion requires. Those still need a Lasna (or mainnet) deployment and the transaction hashes. See `SUBMISSION.md`.
- The documented deploy path is Lasna plus Base Sepolia, which the chain table lists as a testnet origin and destination. Reactive Meets AI is allowed to use Lasna. No deploy was performed.
- Price age uses timestamps, not block counts.
- Dependencies (`forge-std`, `reactive-lib-omni`) are prior work used as libraries. The Aegis contracts, scorer, and demo were written for this event.
- License of this repo: MIT. `reactive-lib-omni` source files are marked `UNLICENSED` upstream and are not relicensed here.
