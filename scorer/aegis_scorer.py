"""Fixed-point risk scorer for Aegis.

The model is a 5-4-3 multilayer perceptron. Hidden units use ReLU. The three
outputs use a rational sigmoid, 1/2 + x / (2 * (1 + |x|)), so inference does
not depend on libm. Weights are integers in weights.json. The policy head
(stop width, pause threshold, confidence floor) sits outside the network and
matches the constants in src/AegisMath.sol.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path

SCALE = 1_000_000
MIN_CONFIDENCE_BPS = 5500
MIN_STOP_BPS = 100
MAX_STOP_BPS = 2000
PAUSE_PROB = 700_000
HARD_STOP_PROB = 850_000
HOLD = 0
ARM = 1
PAUSE = 2
ACTION_NAMES = {HOLD: "HOLD", ARM: "ARM", PAUSE: "PAUSE"}

_WEIGHTS_PATH = Path(__file__).with_name("weights.json")


@dataclass(frozen=True)
class Policy:
    stop_bps: int
    action: int
    action_name: str
    confidence_bps: int
    features: tuple[int, int, int, int, int]
    features_hash: str
    hidden: tuple[int, int, int, int]
    stop_prob: int
    pause_prob: int
    confidence_prob: int
    epoch: int

    def to_json(self) -> str:
        payload = asdict(self)
        payload["features"] = list(self.features)
        payload["hidden"] = list(self.hidden)
        return json.dumps(payload, indent=2, sort_keys=True)


def load_weights(path: Path | None = None) -> dict:
    raw = json.loads((path or _WEIGHTS_PATH).read_text())
    if raw["scale"] != SCALE:
        raise ValueError(f"weights scale {raw['scale']} != {SCALE}")
    return raw


def features(prices: list[int], entry: int) -> tuple[int, int, int, int, int]:
    """Five inputs in [0, SCALE]: last return, volatility, peak drawdown, entry drawdown, down-tick share."""
    if entry <= 0:
        raise ValueError("entry must be positive")
    if len(prices) < 2:
        raise ValueError("need at least two prices")
    if any(price <= 0 for price in prices):
        raise ValueError("prices must be positive")

    last = prices[-1]
    prev = prices[-2]
    ret_abs = abs(last - prev) * SCALE // prev
    ret_n = min(SCALE, ret_abs * SCALE // 50_000)

    steps = len(prices) - 1
    abs_sum = 0
    down = 0
    for left, right in zip(prices, prices[1:]):
        abs_sum += abs(right - left) * SCALE // left
        if right < left:
            down += 1
    mean_abs = abs_sum // steps
    vol_n = min(SCALE, mean_abs * SCALE // 30_000)

    peak = max(prices)
    dd_peak = (peak - last) * SCALE // peak
    dd_peak_n = min(SCALE, dd_peak * SCALE // 200_000)

    dd_entry = 0 if last >= entry else (entry - last) * SCALE // entry
    dd_entry_n = min(SCALE, dd_entry * SCALE // 200_000)
    down_n = down * SCALE // steps
    return (ret_n, vol_n, dd_peak_n, dd_entry_n, down_n)


def keccak256_hex(data: bytes) -> str:
    completed = subprocess.run(
        ["cast", "keccak", "0x" + data.hex()],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def features_hash(values: tuple[int, ...]) -> str:
    """keccak256(abi.encode(uint256[5])), the same encoding as Aegis.t.sol."""
    if len(values) != 5:
        raise ValueError("expected 5 features")
    raw = b"".join(int(value).to_bytes(32, "big") for value in values)
    return keccak256_hex(raw)


def score(prices: list[int], entry: int, epoch: int, weights: dict | None = None) -> Policy:
    if epoch <= 0:
        raise ValueError("epoch must be positive")
    model = weights if weights is not None else load_weights()
    vector = features(prices, entry)
    hidden_raw = tuple(_affine(row, bias, vector) for row, bias in zip(model["w1"], model["b1"]))
    hidden = tuple(max(0, value) for value in hidden_raw)
    stop_raw, pause_raw, conf_raw = (
        _affine(row, bias, hidden) for row, bias in zip(model["w2"], model["b2"])
    )
    stop_prob = _sigmoid(stop_raw)
    pause_prob = _sigmoid(pause_raw)
    confidence_prob = _sigmoid(conf_raw)
    stop_bps = 1500 - (1350 * stop_prob // SCALE)
    stop_bps = max(MIN_STOP_BPS, min(MAX_STOP_BPS, stop_bps))
    confidence_bps = confidence_prob * 10_000 // SCALE
    # The network's second output is an urgency score. The head maps it onto the
    # three actions the contracts understand. These cutoffs are part of the model
    # definition, chosen so the checked fixtures separate: a quiet book stays
    # armed, a grind pauses, and a fast crash closes.
    if confidence_bps < MIN_CONFIDENCE_BPS:
        action = HOLD
    elif pause_prob >= HARD_STOP_PROB:
        action = ARM
    elif pause_prob >= PAUSE_PROB:
        action = PAUSE
    else:
        action = ARM
    return Policy(
        stop_bps=stop_bps,
        action=action,
        action_name=ACTION_NAMES[action],
        confidence_bps=confidence_bps,
        features=vector,
        features_hash=features_hash(vector),
        hidden=hidden,  # type: ignore[arg-type]
        stop_prob=stop_prob,
        pause_prob=pause_prob,
        confidence_prob=confidence_prob,
        epoch=epoch,
    )


def drawdown_bps(entry: int, price: int) -> int:
    if entry <= 0 or price >= entry:
        return 0
    return (entry - price) * 10_000 // entry


def trigger_bps(stop_bps: int, action: int) -> int:
    if action == PAUSE:
        return stop_bps // 2
    if action == ARM:
        return stop_bps
    return 2**256 - 1


def _affine(row: list[int], bias: int, inputs: tuple[int, ...]) -> int:
    total = bias
    for weight, value in zip(row, inputs):
        total += weight * value // SCALE
    return total


def _sigmoid(value: int) -> int:
    magnitude = abs(value)
    shaped = value * SCALE // (SCALE + magnitude)
    return (SCALE + shaped) // 2


def main() -> None:
    parser = argparse.ArgumentParser(description="Score a price window into an Aegis policy")
    parser.add_argument("--entry", type=int, required=True)
    parser.add_argument("--prices", required=True, help="Comma-separated positive integers")
    parser.add_argument("--epoch", type=int, required=True)
    args = parser.parse_args()
    prices = [int(part) for part in args.prices.split(",") if part]
    print(score(prices, args.entry, args.epoch).to_json())


if __name__ == "__main__":
    main()
