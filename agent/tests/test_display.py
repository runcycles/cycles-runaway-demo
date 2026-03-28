"""Tests for display.py — DemoState dataclass logic, no terminal needed."""
from __future__ import annotations

import sys
import os
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from display import BUDGET_MICROCENTS, MICROCENTS_PER_USD, THRESHOLDS, DemoState


def test_demo_state_initial_values():
    state = DemoState(mode="UNGUARDED", ticket="test")
    assert state.calls == 0
    assert state.spend_microcents == 0
    assert state.stopped is False
    assert state.stop_reason == ""


def test_record_call_increments_counters():
    state = DemoState(mode="UNGUARDED", ticket="test")
    state.record_call(1_000_000, "draft_response")
    assert state.calls == 1
    assert state.spend_microcents == 1_000_000

    state.record_call(1_000_000, "evaluate_quality", score=6.2)
    assert state.calls == 2
    assert state.spend_microcents == 2_000_000
    assert state.last_score == 6.2
    assert state.last_action == "evaluate_quality"


def test_spend_usd_conversion():
    state = DemoState(mode="UNGUARDED", ticket="test")
    state.spend_microcents = MICROCENTS_PER_USD  # $1.00
    assert state.spend_usd == 1.0

    state.spend_microcents = 50_000_000  # $0.50
    assert state.spend_usd == 0.5


def test_threshold_crossing():
    state = DemoState(mode="UNGUARDED", ticket="test")
    # Spend below first threshold ($0.10 = 10_000_000 microcents)
    state.record_call(5_000_000, "call1")
    assert 10_000_000 not in state.threshold_crossed

    # Spend above first threshold
    state.record_call(6_000_000, "call2")
    assert 10_000_000 in state.threshold_crossed
    call_num, _ = state.threshold_crossed[10_000_000]
    assert call_num == 2


def test_threshold_not_crossed_twice():
    state = DemoState(mode="UNGUARDED", ticket="test")
    state.record_call(15_000_000, "call1")
    first_entry = state.threshold_crossed[10_000_000]

    state.record_call(1_000_000, "call2")
    assert state.threshold_crossed[10_000_000] == first_entry


def test_calls_per_second():
    state = DemoState(mode="UNGUARDED", ticket="test")
    # With 0 calls, should be 0
    assert state.calls_per_second == 0.0

    state.calls = 10
    # elapsed > 0 since start_time was set
    assert state.calls_per_second >= 0.0


def test_mode_values():
    guarded = DemoState(mode="GUARDED", ticket="test")
    unguarded = DemoState(mode="UNGUARDED", ticket="test")
    assert guarded.mode == "GUARDED"
    assert unguarded.mode == "UNGUARDED"


def test_thresholds_are_ordered():
    values = [mc for mc, _ in THRESHOLDS]
    assert values == sorted(values)


def test_budget_microcents_matches_highest_threshold():
    highest = max(mc for mc, _ in THRESHOLDS)
    assert BUDGET_MICROCENTS == highest
