"""
Guarded agent — budget enforced by RunCycles.

Identical to unguarded.py except:
  1. Each LLM function is wrapped with @cycles
  2. BudgetExceededError is caught at the call site

Three decorators. One except. That is the entire integration.
"""
from __future__ import annotations

import os

from runcycles import BudgetExceededError, CyclesClient, CyclesConfig, cycles, set_default_client

from display import DemoDisplay, DemoState
from simulation import (
    COST_PER_CALL_MICROCENTS, QUALITY_THRESHOLD,
    draft_response as _draft, evaluate_quality as _eval, refine_response as _refine,
)

TICKET = "My invoice for March is showing $847 but my contract says $720."


def _setup():
    config = CyclesConfig(
        base_url=os.environ["CYCLES_BASE_URL"],
        api_key=os.environ["CYCLES_API_KEY"],
        tenant=os.environ["CYCLES_TENANT"],
        agent="support-bot",
    )
    set_default_client(CyclesClient(config))


@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="draft-response")
def draft_response(ticket_text: str) -> str:
    return _draft(ticket_text)


@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="evaluate-quality")
def evaluate_quality(draft: str) -> float:
    return _eval(draft)


@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="refine-response")
def refine_response(draft: str, score: float) -> str:
    return _refine(draft, score)


def run() -> None:
    _setup()
    state = DemoState(mode="GUARDED", ticket=f"#4782 — {TICKET[:48]}...")

    with DemoDisplay(state) as display:
        try:
            draft = draft_response(TICKET)
            state.record_call(COST_PER_CALL_MICROCENTS, "draft_response ✓ reserved + committed")
            display.refresh()

            iteration = 0
            while True:
                iteration += 1

                try:
                    score = evaluate_quality(draft)
                    state.record_call(COST_PER_CALL_MICROCENTS, f"evaluate_quality → score {score:.1f}", score=score)
                    display.refresh()
                except BudgetExceededError:
                    raise

                if score >= QUALITY_THRESHOLD:
                    state.stopped = True
                    state.stop_reason = "quality threshold met"
                    break

                try:
                    draft = refine_response(draft, score)
                    state.record_call(COST_PER_CALL_MICROCENTS, "refine_response ✓ reserved + committed")
                    display.refresh()
                except BudgetExceededError:
                    raise

        except BudgetExceededError:
            state.stopped = True
            state.stop_reason = "BUDGET_EXCEEDED — Cycles server returned 409"
            state.last_action = "POST /v1/reservations → 409 BUDGET_EXCEEDED\n    BudgetExceededError raised — agent stopped cleanly"
            display.refresh()


if __name__ == "__main__":
    run()
