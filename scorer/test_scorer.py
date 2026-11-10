"""Unit tests for the deterministic Aegis scorer."""

from __future__ import annotations

import unittest
from unittest import mock

from scorer.aegis_scorer import (
    ARM,
    HOLD,
    PAUSE,
    drawdown_bps,
    features_hash,
    load_weights,
    score,
    trigger_bps,
)
from scorer.llm_hook import llm_note

ENTRY = 100_000_000_000


def _calm() -> list[int]:
    return [
        ENTRY,
        ENTRY + 100_000_000,
        ENTRY - 100_000_000,
        ENTRY + 200_000_000,
        ENTRY - 50_000_000,
        ENTRY + 50_000_000,
        ENTRY,
    ]


def _grind() -> list[int]:
    price = ENTRY
    series = [price]
    for _ in range(3):
        price = price * 99 // 100
        series.append(price)
    return series


def _crash() -> list[int]:
    price = ENTRY
    series = [price]
    for _ in range(7):
        price = price * 97 // 100
        series.append(price)
    return series


def _wick() -> list[int]:
    return [ENTRY, ENTRY, ENTRY, ENTRY * 94 // 100, ENTRY]


class ScorerTest(unittest.TestCase):
    def test_hash_matches_solidity_vector(self) -> None:
        self.assertEqual(
            features_hash((1, 2, 3, 4, 5)),
            "0x5917e5a395fb9b454434de59651d36822a9e29c5ec57474df3e67937b969460c",
        )

    def test_score_is_deterministic(self) -> None:
        first = score(_crash(), ENTRY, 3)
        second = score(_crash(), ENTRY, 3)
        self.assertEqual(first, second)

    def test_calm_arms_a_wide_stop(self) -> None:
        policy = score(_calm(), ENTRY, 1)
        self.assertEqual(policy.action, ARM)
        self.assertGreaterEqual(policy.confidence_bps, 5500)
        self.assertGreaterEqual(policy.stop_bps, 800)
        self.assertLessEqual(policy.stop_bps, 2000)

    def test_grind_pauses_and_crash_closes(self) -> None:
        calm = score(_calm(), ENTRY, 1)
        grind = score(_grind(), ENTRY, 2)
        crash = score(_crash(), ENTRY, 3)
        self.assertEqual(grind.action, PAUSE)
        self.assertGreaterEqual(grind.confidence_bps, 5500)
        self.assertGreaterEqual(drawdown_bps(ENTRY, _grind()[-1]), trigger_bps(grind.stop_bps, grind.action))
        self.assertEqual(crash.action, ARM)
        self.assertGreaterEqual(crash.confidence_bps, 5500)
        self.assertLessEqual(crash.stop_bps, 400)
        self.assertLess(crash.stop_bps, calm.stop_bps)
        self.assertGreaterEqual(drawdown_bps(ENTRY, _crash()[-1]), trigger_bps(crash.stop_bps, crash.action))

    def test_recovered_wick_is_not_actionable(self) -> None:
        policy = score(_wick(), ENTRY, 4)
        self.assertEqual(policy.action, HOLD)
        self.assertLess(policy.confidence_bps, 5500)

    def test_rejects_bad_windows(self) -> None:
        with self.assertRaises(ValueError):
            score([ENTRY], ENTRY, 1)
        with self.assertRaises(ValueError):
            score(_calm(), 0, 1)
        with self.assertRaises(ValueError):
            score(_calm(), ENTRY, 0)

    def test_weights_file_loads(self) -> None:
        weights = load_weights()
        self.assertEqual(len(weights["w1"]), 4)
        self.assertEqual(len(weights["w1"][0]), 5)
        self.assertEqual(len(weights["w2"]), 3)
        self.assertEqual(weights["b2"][1], -350_000)

    def test_default_path_does_not_call_the_llm_hook(self) -> None:
        with mock.patch("scorer.llm_hook.urllib.request.urlopen", side_effect=AssertionError("network")):
            policy = score(_calm(), ENTRY, 1)
            self.assertIsNone(llm_note(policy.to_json(), enabled=False, url="http://127.0.0.1:9"))
        self.assertEqual(policy.action, ARM)

    def test_enabled_hook_without_url_does_not_dial(self) -> None:
        with mock.patch("scorer.llm_hook.urllib.request.urlopen", side_effect=AssertionError("network")):
            self.assertEqual(llm_note("hello", enabled=True, url=None), "llm-hook-skipped-no-url")


if __name__ == "__main__":
    unittest.main()
