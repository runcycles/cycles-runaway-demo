"""
Simulated LLM calls. No API key required.

The quality evaluator always returns below QUALITY_THRESHOLD.
This is the bug. The agent loops forever.
"""
from __future__ import annotations

import random
import time

CALL_LATENCY_S: float = 0.05           # 50ms; real LLM: 500ms-2000ms
QUALITY_THRESHOLD: float = 8.0         # agent accepts score >= 8.0
MAX_QUALITY_SCORE: float = 6.9         # evaluator never exceeds this (the bug)
COST_PER_CALL_MICROCENTS: int = 1_000_000 # $0.01 per call
DEMO_MAX_RUNTIME_S: int = 30           # unguarded auto-stop (remove for unbounded)


class UpstreamError(Exception):
    """Simulates LLM API 503."""


def draft_response(ticket_text: str) -> str:
    time.sleep(CALL_LATENCY_S)
    return f"Thank you for contacting support regarding '{ticket_text[:40]}...'"


def evaluate_quality(draft: str) -> float:
    time.sleep(CALL_LATENCY_S)
    return round(random.uniform(5.5, MAX_QUALITY_SCORE), 1)


def refine_response(draft: str, score: float) -> str:
    time.sleep(CALL_LATENCY_S)
    return f"[Refined v{int(score * 10)}] {draft}"
