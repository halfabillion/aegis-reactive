"""Local end-to-end demo.

Starts Anvil, deploys the Aegis contracts, and walks one feed through the
scorer, origin events, react(), and the destination callback. Anvil's
unlocked default account sends every transaction. No private key is read
or printed. This is not a Lasna deployment.
"""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from scorer.aegis_scorer import (  # noqa: E402
    ARM,
    HOLD,
    PAUSE,
    drawdown_bps,
    score,
    trigger_bps,
)

RPC = os.environ.get("AEGIS_RPC", "http://127.0.0.1:18545")
PORT = "18545"
FROM = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
SYSTEM = "0x8888888888888888888888888888888888888888"
ORIGIN_CHAIN = "11155111"
DEST_CHAIN = "84532"
FEED = 1
ENTRY = 100_000_000_000
SIZE = 1_000_000
FORGE_BIN = os.environ.get("FOUNDRY_BIN", str(Path.home() / ".foundry" / "bin"))
os.environ["PATH"] = FORGE_BIN + os.pathsep + os.environ.get("PATH", "")


def main() -> None:
    anvil = _start_anvil()
    try:
        _wait_for_rpc()
        print("Aegis local demo")
        print("Anvil chain 31337. Origin chain id in the logs is 11155111 (Ethereum Sepolia).")
        print("Destination chain id on callbacks is 84532 (Base Sepolia).")
        print("The system contract is etched at 0x8888…8888, which is the Omni address.")
        print("No public network is contacted and no key is used.\n")

        mock = _deploy("src/local/MockSystem.sol:MockSystem")
        code = _cast("code", mock).strip()
        if code in {"", "0x"}:
            raise SystemExit("mock system has no code")
        _cast("rpc", "anvil_setCode", SYSTEM, code)
        etched = _cast("code", SYSTEM).strip()
        if etched in {"", "0x"}:
            raise SystemExit("failed to etch the mock system onto 0x8888…8888")

        origin = _deploy("src/origin/AegisOrigin.sol:AegisOrigin")
        reactive = _deploy(
            "src/reactive/AegisReactive.sol:AegisReactive",
            ORIGIN_CHAIN,
            DEST_CHAIN,
            origin,
        )
        relay = _deploy("src/local/CallbackRelay.sol:CallbackRelay")
        vault = _deploy(
            "src/destination/AegisVault.sol:AegisVault",
            relay,
            reactive,
        )
        _send(reactive, "setVault(address)", vault)

        subs = int(_call(SYSTEM, "subscriptionCount()(uint256)"))
        print(f"deployed origin     {origin}")
        print(f"deployed reactive   {reactive}")
        print(f"deployed relay      {relay}")
        print(f"deployed vault      {vault}")
        print(f"subscriptions stored by the system contract: {subs}")
        if subs != 3:
            raise SystemExit("expected 3 subscriptions from the reactive constructor")
        _print_subscriptions()

        timestamp = _now()
        _send(vault, "openPosition(uint256,uint256,uint256)", str(FEED), str(ENTRY), str(SIZE))
        tx = _send(origin, "openPosition(uint256,uint256,uint256)", str(FEED), str(ENTRY), str(SIZE))
        _deliver_tx(tx, reactive)
        entry_on_reactive = _field(reactive, 0)
        print(f"\nposition opened at {ENTRY}. reactive entry is {entry_on_reactive}.")
        if entry_on_reactive != ENTRY:
            raise SystemExit("react() did not store the origin position")

        calm = _window("calm")
        calm_policy = score(calm, ENTRY, 1)
        _print_policy("calm window", calm_policy)
        if calm_policy.action != ARM or calm_policy.stop_bps < 800:
            raise SystemExit("calm policy is not a wide armed stop; the demo cannot show disagreement")
        _post_and_sync(origin, reactive, relay, vault, calm, calm_policy, timestamp)

        flat_tx = _send(
            origin,
            "pushPrice(uint256,uint256,uint64)",
            str(FEED),
            str(ENTRY),
            str(timestamp),
        )
        before = int(_call(SYSTEM, "callbackCount()(uint256)"))
        _deliver_tx(flat_tx, reactive)
        after = int(_call(SYSTEM, "callbackCount()(uint256)"))
        print(f"price at entry. drawdown 0. new callbacks: {after - before} (expected 0)")
        if after != before:
            raise SystemExit("a flat price requested protection")

        wick = _window("wick")
        wick_policy = score(wick, ENTRY, 2)
        _print_policy("recovered wick", wick_policy)
        if wick_policy.action != HOLD:
            raise SystemExit("wick policy was actionable; refusing to post it in this demo")
        wick_tx = _send(
            origin,
            "postPolicy(uint256,uint64,uint16,uint8,uint16,bytes32)",
            str(FEED),
            "2",
            str(wick_policy.stop_bps),
            str(wick_policy.action),
            str(wick_policy.confidence_bps),
            wick_policy.features_hash,
        )
        before = int(_call(SYSTEM, "callbackCount()(uint256)"))
        _deliver_tx(wick_tx, reactive)
        after = int(_call(SYSTEM, "callbackCount()(uint256)"))
        kept = int(_field(reactive, 8))
        print(f"reactive kept stop {kept} bps from epoch 1. new callbacks: {after - before} (expected 0)")
        if after != before or kept != calm_policy.stop_bps:
            raise SystemExit("low-confidence policy replaced the armed stop")

        dip = ENTRY * 98 // 100
        required = trigger_bps(calm_policy.stop_bps, calm_policy.action)
        dip_drawdown = drawdown_bps(ENTRY, dip)
        print(
            f"\ndisagreement check: 2% dip is {dip_drawdown} bps, posted trigger is {required} bps."
        )
        if dip_drawdown >= required:
            raise SystemExit("the calm stop is too tight to demonstrate a refusal")
        payload = _calldata(
            "protect(address,uint256,uint256,uint64,uint64,uint8)",
            "0x0000000000000000000000000000000000000000",
            str(FEED),
            str(dip),
            str(timestamp),
            "1",
            str(ARM),
        )
        refused = _send_allow_revert(
            relay,
            "relay(address,bytes,address)",
            vault,
            payload,
            reactive,
        )
        # cast send estimates gas, so a deliberate revert surfaces as a custom-error selector
        # rather than a mined transaction. 0xa3fd27c5 is ConditionsNotMet(uint256,uint256).
        if "0xa3fd27c5" not in refused and "ConditionsNotMet" not in refused:
            raise SystemExit(f"vault did not refuse the early stop:\n{refused}")
        print(
            f"vault refused with ConditionsNotMet(drawdown={dip_drawdown}, required={required}). "
            "The posted stop is wider than this dip."
        )

        _protect(origin, reactive, relay, vault, "grind", 3, timestamp, expect=PAUSE)
        _protect(origin, reactive, relay, vault, "crash", 4, timestamp, expect=ARM)

        total = int(_call(SYSTEM, "callbackCount()(uint256)"))
        print(f"\ncallback requests recorded: {total}")
        print("demo ok")
    finally:
        if anvil.poll() is None:
            anvil.send_signal(signal.SIGTERM)
            try:
                anvil.wait(timeout=5)
            except subprocess.TimeoutExpired:
                anvil.kill()


def _protect(origin, reactive, relay, vault, name, epoch, timestamp, expect) -> None:
    series = _window(name)
    policy = score(series, ENTRY, epoch)
    _print_policy(f"{name} window", policy)
    if policy.action != expect:
        raise SystemExit(f"{name} action {policy.action_name} != expected {expect}")
    price = series[-1]
    drawdown = drawdown_bps(ENTRY, price)
    required = trigger_bps(policy.stop_bps, policy.action)
    print(f"{name} price {price}. drawdown {drawdown} bps. trigger {required} bps.")
    if drawdown < required:
        raise SystemExit(f"{name} drawdown does not meet the scorer's own trigger")
    _post_and_sync(origin, reactive, relay, vault, series, policy, timestamp)
    price_tx = _send(
        origin,
        "pushPrice(uint256,uint256,uint64)",
        str(FEED),
        str(price),
        str(timestamp),
    )
    before = int(_call(SYSTEM, "callbackCount()(uint256)"))
    _deliver_tx(price_tx, reactive)
    after = int(_call(SYSTEM, "callbackCount()(uint256)"))
    if after != before + 1:
        raise SystemExit(f"react() did not request protection on {name}")
    _relay_last(relay, vault, reactive)
    open_, paused, stopped = _vault_flags(vault)
    print(f"vault open={open_} paused={paused} stopped={stopped}")
    if expect == PAUSE:
        if not (open_ and paused and not stopped):
            raise SystemExit("pause callback did not pause the open position")
        print("protective action: pause. the position is frozen and not closed.")
    elif expect == ARM:
        if not (paused and stopped and not open_):
            raise SystemExit("stop callback did not close the position")
        print("protective action: stop-loss. the mock position is closed.")


def _window(name: str) -> list[int]:
    if name == "calm":
        return [
            ENTRY,
            ENTRY + 100_000_000,
            ENTRY - 100_000_000,
            ENTRY + 200_000_000,
            ENTRY - 50_000_000,
            ENTRY + 50_000_000,
            ENTRY,
        ]
    if name == "wick":
        return [ENTRY, ENTRY, ENTRY, ENTRY * 94 // 100, ENTRY]
    if name == "grind":
        price = ENTRY
        series = [price]
        for _ in range(3):
            price = price * 99 // 100
            series.append(price)
        return series
    if name == "crash":
        price = ENTRY
        series = [price]
        for _ in range(7):
            price = price * 97 // 100
            series.append(price)
        return series
    raise ValueError(name)


def _post_and_sync(origin, reactive, relay, vault, prices, policy, timestamp) -> None:
    del prices, timestamp
    tx = _send(
        origin,
        "postPolicy(uint256,uint64,uint16,uint8,uint16,bytes32)",
        str(FEED),
        str(policy.epoch),
        str(policy.stop_bps),
        str(policy.action),
        str(policy.confidence_bps),
        policy.features_hash,
    )
    before = int(_call(SYSTEM, "callbackCount()(uint256)"))
    _deliver_tx(tx, reactive)
    after = int(_call(SYSTEM, "callbackCount()(uint256)"))
    if after != before + 1:
        raise SystemExit("accepted policy did not request syncPolicy")
    _relay_last(relay, vault, reactive)
    vault_stop = int(_vault_field(vault, 7))
    vault_epoch = int(_vault_field(vault, 6))
    print(f"vault synced epoch {vault_epoch} stop {vault_stop} bps")
    if vault_stop != policy.stop_bps or vault_epoch != policy.epoch:
        raise SystemExit("vault policy does not match the scorer")


def _print_policy(title: str, policy) -> None:
    names = ("return", "vol", "peak_dd", "entry_dd", "down_share")
    pretty = ", ".join(f"{name}={value}" for name, value in zip(names, policy.features))
    hidden = ", ".join(str(value) for value in policy.hidden)
    print(f"\n{title}")
    print(f"  features [{pretty}]")
    print(f"  hidden relu [{hidden}]")
    print(
        f"  probs stop={policy.stop_prob} pause={policy.pause_prob} "
        f"confidence={policy.confidence_prob} (scale 1000000)"
    )
    print(
        f"  policy epoch={policy.epoch} action={policy.action_name} "
        f"stop={policy.stop_bps} bps confidence={policy.confidence_bps} bps"
    )
    print(f"  features hash {policy.features_hash}")


def _print_subscriptions() -> None:
    for index in range(3):
        parts = _tokens(
            _call(
                SYSTEM,
                "getSubscription(uint256)(address,uint256,address,uint256,uint256,uint256,uint256,bool)",
                str(index),
            )
        )
        print(
            f"  sub {index}: chain {parts[1]} origin {parts[2]} "
            f"topic0 {int(parts[3]):#x} wildcard topics active={parts[7]}"
        )


def _deliver_tx(tx_hash: str, reactive: str) -> None:
    receipt = json.loads(_cast("receipt", tx_hash, "--json"))
    logs = receipt["logs"]
    if len(logs) != 1:
        raise SystemExit(f"expected one origin log, got {len(logs)}")
    entry = logs[0]
    topics = entry["topics"]
    block_number = int(receipt["blockNumber"], 16)
    _send(
        SYSTEM,
        "deliver(address,(uint256,address,uint256,uint256,uint256,uint256,bytes,uint256,uint256,uint256,uint256,uint256))",
        reactive,
        "("
        + ",".join(
            [
                ORIGIN_CHAIN,
                entry["address"],
                str(int(topics[0], 16)),
                str(int(topics[1], 16)) if len(topics) > 1 else "0",
                str(int(topics[2], 16)) if len(topics) > 2 else "0",
                str(int(topics[3], 16)) if len(topics) > 3 else "0",
                entry["data"],
                str(block_number),
                str(len(topics)),
                "0",
                "0",
                "0",
            ]
        )
        + ")",
    )


def _relay_last(relay: str, vault: str, reactive: str) -> None:
    payload = _call(SYSTEM, "lastPayload()(bytes)").strip()
    _send(relay, "relay(address,bytes,address)", vault, payload, reactive)


def _field(reactive: str, index: int) -> int:
    row = _call(
        reactive,
        "feeds(uint256)(uint256,uint256,uint256,bool,bool,bool,bool,uint64,uint16,uint8,uint16,bytes32)",
        str(FEED),
    )
    return int(_tokens(row)[index])


def _vault_field(vault: str, index: int) -> str:
    row = _call(
        vault,
        "feeds(uint256)(uint256,uint256,bool,bool,bool,bool,uint64,uint16,uint8,uint16,bytes32)",
        str(FEED),
    )
    return _tokens(row)[index]


def _tokens(text: str) -> list[str]:
    return [part for part in text.split() if not (part.startswith("[") and part.endswith("]"))]


def _vault_flags(vault: str) -> tuple[bool, bool, bool]:
    return (
        _vault_field(vault, 2) == "true",
        _vault_field(vault, 3) == "true",
        _vault_field(vault, 4) == "true",
    )


def _start_anvil() -> subprocess.Popen:
    log_path = Path("/tmp/aegis-anvil.log")
    log = log_path.open("w")
    process = subprocess.Popen(
        ["anvil", "--host", "127.0.0.1", "--port", PORT, "--chain-id", "31337", "--silent"],
        stdout=log,
        stderr=subprocess.STDOUT,
        cwd=ROOT,
    )
    return process


def _wait_for_rpc() -> None:
    last = ""
    for _ in range(50):
        try:
            _cast("block-number")
            return
        except subprocess.CalledProcessError as exc:
            last = exc.stderr or str(exc)
            time.sleep(0.1)
    raise SystemExit(f"anvil did not answer on port 18545\n{last}")


def _deploy(spec: str, *args: str) -> str:
    command = [
        "forge",
        "create",
        spec,
        "--rpc-url",
        RPC,
        "--unlocked",
        "--from",
        FROM,
        "--broadcast",
        "--root",
        str(ROOT),
    ]
    if args:
        command.append("--constructor-args")
        command.extend(args)
    completed = subprocess.run(command, cwd=ROOT, check=True, capture_output=True, text=True)
    for line in completed.stdout.splitlines():
        if "Deployed to:" in line:
            return line.split()[-1]
    raise SystemExit(f"deploy failed for {spec}\n{completed.stdout}\n{completed.stderr}")


def _send(to: str, signature: str, *args: str) -> str:
    completed = _run(["cast", "send", "--json", "--unlocked", "--from", FROM, "--rpc-url", RPC, to, signature, *args])
    if completed.returncode != 0:
        raise SystemExit(f"send {signature} failed\n{completed.stdout}\n{completed.stderr}")
    payload = json.loads(completed.stdout)
    return payload["transactionHash"]


def _send_allow_revert(to: str, signature: str, *args: str) -> str:
    completed = _run(["cast", "send", "--unlocked", "--from", FROM, "--rpc-url", RPC, to, signature, *args])
    return completed.stdout + completed.stderr


def _call(to: str, signature: str, *args: str) -> str:
    completed = _run(["cast", "call", "--rpc-url", RPC, to, signature, *args])
    if completed.returncode != 0:
        raise SystemExit(f"call {signature} failed\n{completed.stderr}")
    return completed.stdout.strip()


def _calldata(signature: str, *args: str) -> str:
    return _cast("calldata", signature, *args).strip()


def _cast(*args: str) -> str:
    if args[0] == "calldata":
        command = ["cast", *args]
    else:
        command = ["cast", args[0], "--rpc-url", RPC, *args[1:]]
    completed = _run(command)
    if completed.returncode != 0:
        detail = (completed.stderr or "") + (completed.stdout or "")
        raise subprocess.CalledProcessError(completed.returncode, command, completed.stdout, detail)
    return completed.stdout


def _now() -> int:
    raw = _cast("block", "latest", "--field", "timestamp").strip()
    return int(raw, 0) if raw.startswith("0x") else int(raw)


def _run(command: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True)


if __name__ == "__main__":
    main()
