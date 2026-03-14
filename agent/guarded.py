"""
Guarded agent — budget enforced by RunCycles.

Identical to unguarded.py except:
  1. Each LLM function is wrapped with @cycles
  2. BudgetExceededError is caught at the call site

Three decorators. One except. That is the entire integration.
"""
from __future__ import annotations

import os
import signal
import sys
import time

from runcycles import BudgetExceededError, CyclesClient, CyclesConfig, cycles, set_default_client
from runcycles.exceptions import CyclesError

from display import DemoDisplay, DemoState
from simulation import (
    COST_PER_CALL_MICROCENTS, QUALITY_THRESHOLD,
    draft_response as _draft, evaluate_quality as _eval, refine_response as _refine,
)

TICKET = "My invoice for March is showing $847 but my contract says $720."


def _setup():
    missing = [v for v in ("CYCLES_BASE_URL", "CYCLES_API_KEY", "CYCLES_TENANT") if v not in os.environ]
    if missing:
        print(f"ERROR: Missing environment variables: {', '.join(missing)}", file=sys.stderr)
        print("  These are set automatically by demo.sh.", file=sys.stderr)
        print("  Run the demo with: ./demo.sh guarded", file=sys.stderr)
        sys.exit(1)

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
    exit_error: str | None = None

    def _sigint(sig, frame):
        state.stopped = True
        state.stop_reason = "Ctrl+C"

    signal.signal(signal.SIGINT, _sigint)

    with DemoDisplay(state) as display:
        try:
            # Initial draft
            draft = draft_response(TICKET)
            state.record_call(COST_PER_CALL_MICROCENTS, "draft_response")
            display.refresh()

            iteration = 0
            while not state.stopped:
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

        except BudgetExceededError:
            state.stopped = True
            state.stop_reason = "BUDGET_EXCEEDED — Cycles server returned 409"
            state.last_action = "POST /v1/reservations → 409 BUDGET_EXCEEDED\n    BudgetExceededError raised — agent stopped cleanly"
            display.refresh()

        except CyclesError as e:
            state.stopped = True
            err_str = str(e)
            state.last_action = f"ERROR: {err_str}"
            display.refresh()

            if "Connection refused" in err_str or "timed out" in err_str.lower():
                state.stop_reason = f"connection error — {err_str}"
                exit_error = (
                    f"\nERROR: Cannot reach Cycles server at {os.environ['CYCLES_BASE_URL']}\n"
                    f"  Is the stack running?  docker compose ps\n"
                    f"  Check server logs:     docker compose logs cycles-server"
                )
            else:
                state.stop_reason = f"unexpected error — {err_str}"
                exit_error = (
                    f"\nERROR: Cycles error: {err_str}\n"
                    f"  Check server logs: docker compose logs cycles-server"
                )

    # Print error AFTER the final panel (display.__exit__ already printed it)
    if exit_error:
        print(exit_error, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    run()
