# Aegis video shot list

Target length **2:30**. Hard stop at 3:00. The recorded file is `video/aegis-demo.mp4`: 1920×1080, 160 seconds (2:40). There is no voice track. The narration below is burned in as captions. The PriceUpdated log tab on BaseScan stays closed; the transaction overview is what the recording shows. Lasna Reactscan shows the react input and the Base Sepolia callback as relayed, included, and posted.

Shots 5–7 use the crash transactions already listed in [DEPLOYMENTS.md](DEPLOYMENTS.md). Open those pages. Do not type a hash from memory.

Do not open `.secrets`, a key file, or a faucet page.

## Setup

Terminal: one window, about 90 columns, monospace at 16px. Browser: one window, zoom 100%, bookmarks bar hidden.

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /path/to/aegis
```

Have these already run once so the recording is not waiting on compilation:

```bash
forge test
python3 -m unittest discover -s scorer -v
```

You do not need to show those full runs. The demo is the picture.

## Shot 1 — Problem (0:00–0:18)

On screen: README title and the Problem section, scrolled so the first two paragraphs fill the window.

Narration:

"Aegis is for the Reactive Meets AI track. A fixed stop is a poor fit for both a quiet market and a fast selloff. A small neural net retunes the width. The chain still has to see the drawdown before anything closes."

## Shot 2 — Architecture (0:18–0:40)

On screen: the mermaid diagram in the README. If the preview does not render, show this terminal block instead, same words:

```text
scorer  ->  origin policy event
origin  ->  Lasna react()
react   ->  Base Sepolia callback
callback -> vault pauses or closes
```

Narration:

"The scorer reads a short price window and posts a policy: stop width, hold or arm or pause, and a confidence. The reactive contract subscribes to that event and to prices. It requests a callback only when the drawdown meets the policy. The vault checks the callback proxy, the reactive sender, and its own entry price, then pauses or closes."

## Shot 3 — Local demo (0:40–1:25)

On screen: the terminal. Run:

```bash
./demo/demo.sh
```

Scroll, in order, to these lines and leave each visible for a couple of seconds:

1. `subscriptions stored by the system contract: 3`
2. calm policy `action=ARM stop=911 bps`
3. `vault refused with ConditionsNotMet(drawdown=200, required=911)`
4. grind `action=PAUSE` and `protective action: pause`
5. crash `action=ARM stop=270 bps` and `protective action: stop-loss`
6. `callback requests recorded: 5` and `demo ok`

Narration:

"This is Anvil, not Lasna. The constructor subscribed to three origin events. A calm window arms a stop of 911 basis points, and a two percent dip is refused because the drawdown is only 200. A grind pauses the position and leaves it open. A fast crash tightens the stop to 270 and the vault closes. Five callback requests, and the demo ends ok."

## Shot 4 — Where the hashes live (1:25–1:35)

On screen: the crash rows in `DEPLOYMENTS.md`.

Narration:

"The same contracts are on Base Sepolia and Lasna. These three hashes are the crash price, the Lasna react, and the stop callback."

## Shot 5 — Origin event (1:35–1:50)

On screen:

```text
https://sepolia.basescan.org/tx/0x3ee6064a848d7b12509f04e03c118e5a5f2c2f0e5ebaa067e9d26c806e9d7f51
```

Point at the `PriceUpdated` log.

Narration:

"On Base Sepolia the origin contract emits PriceUpdated. This is the crash price from the same window as the local demo."

## Shot 6 — Lasna react (1:50–2:05)

On screen:

```text
https://lasna.reactscan.net/tx/0x09950b9198f059bb14ac1b588b188b1e0c2fab88c21286e1966f8f711e1d2c27
```

Point at `ProtectionRequested` on `AegisReactive`.

Narration:

"Lasna delivers that log to react. The reactive contract holds the entry and the 270 basis point stop, and this transaction requests the destination callback."

## Shot 7 — Destination callback (2:05–2:18)

On screen:

```text
https://sepolia.basescan.org/tx/0xc97663076f6aa11c5e86e01c79ce08513a11f0bd649c95fa7db19f80a671156c
```

The transaction is sent to the callback proxy `0x476F44b11F5C942c58f4c8E3d0300E5710743585`. Point at the call into the vault.

Narration:

"The callback lands on Base Sepolia. The vault ends stopped. The grind callback had already paused it. This stop is the close."

## Shot 8 — Close (2:18–2:30)

On screen: `scorer/weights.json` first lines, then the last line of the demo (`demo ok`). Do not show a key.

Narration:

"The model is a fixed-point network with hand-set weights, and the demo calls it before every policy. A language-model hook exists and stays off. The video stays under three minutes."

The public repository link and this recording are still not done. Say that in the last sentence if you have not published either one.
