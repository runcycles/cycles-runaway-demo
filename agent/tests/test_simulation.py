"""Tests for simulation.py — pure functions, no server needed."""
from __future__ import annotations

import sys
import os

# Allow imports from agent/ directory
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from simulation import (
    COST_PER_CALL_MICROCENTS,
    MAX_QUALITY_SCORE,
    QUALITY_THRESHOLD,
    draft_response,
    evaluate_quality,
    refine_response,
)


def test_quality_threshold_always_unreachable():
    """The core bug: MAX_QUALITY_SCORE < QUALITY_THRESHOLD, so the loop never exits."""
    assert MAX_QUALITY_SCORE < QUALITY_THRESHOLD


def test_draft_response_returns_string():
    result = draft_response("My invoice is wrong")
    assert isinstance(result, str)
    assert len(result) > 0


def test_draft_response_includes_ticket_text():
    result = draft_response("My invoice is wrong")
    assert "invoice" in result.lower()


def test_evaluate_quality_within_range():
    scores = [evaluate_quality("some draft") for _ in range(20)]
    for score in scores:
        assert 5.5 <= score <= MAX_QUALITY_SCORE


def test_evaluate_quality_never_meets_threshold():
    scores = [evaluate_quality("some draft") for _ in range(50)]
    for score in scores:
        assert score < QUALITY_THRESHOLD


def test_refine_response_includes_version():
    result = refine_response("original draft", 6.5)
    assert result.startswith("[Refined v")
    assert "original draft" in result


def test_cost_per_call_is_positive():
    assert COST_PER_CALL_MICROCENTS > 0
