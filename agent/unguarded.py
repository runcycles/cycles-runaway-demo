"""
Runaway agent — no budget enforcement.

The refinement loop has no exit condition other than quality score.
The quality evaluator never returns above threshold.
Auto-terminates after DEMO_MAX_RUNTIME_S seconds (remove for truly unbounded).
"""
from __future__ import annotations

import signal
import time

from display import DemoDisplay, DemoState
from simulation import (
    COST_PER_CALL_MICROCENTS, QUALITY_THRESHOLD, DEMO_MAX_RUNTIME_S,
    draft_response, evaluate_quality, refine_response,
)

TICKET = "My invoice for March is showing $847 but my contract says $720."


def run() -> None:
    state = DemoState(mode="UNGUARDED", ticket=f"#4782 — {TICKET[:48]}...")

    def _sigint(sig, frame):
        state.stopped = True
        state.stop_reason = "Ctrl+C"

    signal.signal(signal.SIGINT, _sigint)

    with DemoDisplay(state) as display:
        # Initial draft
        draft = draft_response(TICKET)
        state.record_call(COST_PER_CALL_MICROCENTS, "draft_response")
        display.refresh()

        iteration = 0
        while not state.stopped:
            if time.monotonic() - state.start_time > DEMO_MAX_RUNTIME_S:
                state.stopped = True
                state.stop_reason = f"auto-stop after {DEMO_MAX_RUNTIME_S}s"
                break
            iteration += 1

            score = evaluate_quality(draft)
            state.record_call(COST_PER_CALL_MICROCENTS, f"evaluate_quality (iter {iteration})", score=score)
            display.refresh()

            if score >= QUALITY_THRESHOLD:
                state.stopped = True
                state.stop_reason = "quality threshold met"
                break

            draft = refine_response(draft, score)
            state.record_call(COST_PER_CALL_MICROCENTS, f"refine_response (score was {score:.1f})")
            display.refresh()


if __name__ == "__main__":
    run()
