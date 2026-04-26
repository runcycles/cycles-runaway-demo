"""
Drives a single end-to-end recording: unguarded for ~12s, hard cut to a
"MODE 2" interstitial, then guarded to its natural BUDGET_EXCEEDED stop,
ending on a green two-column summary card.

Invoked by demo.tape inside vhs. Assumes the Cycles stack is up and
CYCLES_BASE_URL / CYCLES_API_KEY / CYCLES_TENANT are exported (record.sh
handles that before launching vhs).
"""
from __future__ import annotations

import time

from rich.console import Console
from rich.panel import Panel
from rich.text import Text

from display import DemoDisplay, DemoState
# `import simulation` (bare) is needed alongside the `from simulation import`
# below: we monkey-patch `simulation.CALL_LATENCY_S` for the unguarded
# segment, which only works through the module reference. The named imports
# below are evaluated once at import time, so reassigning them here would
# not change the value the simulation functions actually read.
import simulation  # noqa: E402,F401  (used for runtime monkey-patch)
from simulation import (
    COST_PER_CALL_MICROCENTS, QUALITY_THRESHOLD,
    draft_response as _sim_draft, evaluate_quality as _sim_eval,
    refine_response as _sim_refine,
)

# guarded.py defines decorated wrappers and the _setup() that points the
# SDK at the running Cycles stack. We reuse them as-is.
from guarded import (
    _setup as _guarded_setup,
    draft_response as _guarded_draft,
    evaluate_quality as _guarded_eval,
    refine_response as _guarded_refine,
)
from runcycles import BudgetExceededError

TICKET = "My invoice for March is showing $847 but my contract says $720."
UNGUARDED_RUNTIME_S = 12.0
INTERSTITIAL_HOLD_S = 1.5
BUDGET_EXCEEDED_HOLD_S = 3.5
SUMMARY_HOLD_S = 5.0

# The live demo (./demo.sh) runs simulation.CALL_LATENCY_S = 50ms, which in
# 12s burns ~$2.40. For the recorded GIF we drop latency just for the
# unguarded segment so the contrast at the end (~$10 vs $1.00) is dramatic.
# Guarded runs at the original rate so the BUDGET_EXCEEDED moment lands at
# 100 calls / ~7s as documented.
UNGUARDED_RECORDING_LATENCY_S = 0.011


def _print_mode_banner(console: Console, line1: str, line2: str | None = None,
                       border_style: str = "red") -> None:
    rule = "━" * 44
    console.print(rule, style=border_style)
    console.print(f"  {line1}", style=f"bold {border_style}")
    if line2:
        console.print(f"  {line2}", style=f"dim {border_style}")
    console.print(rule, style=border_style)
    console.print()


def run_unguarded(console: Console) -> tuple[DemoState, float]:
    state = DemoState(mode="UNGUARDED", ticket=f"#4782 — {TICKET[:48]}...")
    original_latency = simulation.CALL_LATENCY_S
    simulation.CALL_LATENCY_S = UNGUARDED_RECORDING_LATENCY_S
    try:
        with DemoDisplay(state) as display:
            draft = _sim_draft(TICKET)
            state.record_call(COST_PER_CALL_MICROCENTS, "draft_response")
            display.refresh()

            iteration = 0
            while not state.stopped:
                if state.elapsed > UNGUARDED_RUNTIME_S:
                    state.stopped = True
                    state.stop_reason = f"cut at {UNGUARDED_RUNTIME_S:.0f}s — projection still climbing"
                    break
                iteration += 1

                score = _sim_eval(draft)
                state.record_call(
                    COST_PER_CALL_MICROCENTS,
                    f"evaluate_quality (iter {iteration})",
                    score=score,
                )
                display.refresh()

                if score >= QUALITY_THRESHOLD:
                    state.stopped = True
                    state.stop_reason = "quality threshold met"
                    break

                draft = _sim_refine(draft, score)
                state.record_call(
                    COST_PER_CALL_MICROCENTS,
                    f"refine_response (score was {score:.1f})",
                )
                display.refresh()
            final_elapsed = state.elapsed
    finally:
        simulation.CALL_LATENCY_S = original_latency
    return state, final_elapsed


def run_guarded(console: Console) -> DemoState:
    _guarded_setup()
    state = DemoState(mode="GUARDED", ticket=f"#4782 — {TICKET[:48]}...")
    with DemoDisplay(state) as display:
        try:
            draft = _guarded_draft(TICKET)
            state.record_call(COST_PER_CALL_MICROCENTS, "draft_response")
            display.refresh()

            iteration = 0
            while not state.stopped:
                iteration += 1

                score = _guarded_eval(draft)
                state.record_call(
                    COST_PER_CALL_MICROCENTS,
                    f"evaluate_quality (iter {iteration})",
                    score=score,
                )
                display.refresh()

                if score >= QUALITY_THRESHOLD:
                    state.stopped = True
                    state.stop_reason = "quality threshold met"
                    break

                draft = _guarded_refine(draft, score)
                state.record_call(
                    COST_PER_CALL_MICROCENTS,
                    f"refine_response (score was {score:.1f})",
                )
                display.refresh()

        except BudgetExceededError:
            state.stopped = True
            state.stop_reason = "BUDGET_EXCEEDED — Cycles server returned 409"
            state.last_action = (
                "POST /v1/reservations → 409 BUDGET_EXCEEDED\n"
                "    BudgetExceededError raised — agent stopped cleanly"
            )
            display.refresh()
    return state


def main() -> None:
    console = Console()

    _print_mode_banner(console, "MODE 1: WITHOUT CYCLES", border_style="red")
    unguarded, unguarded_elapsed = run_unguarded(console)

    console.clear()
    interstitial = Panel(
        Text.from_markup(
            "[bold green]MODE 2: WITH CYCLES[/bold green]\n"
            "[dim]same agent · same bug[/dim]"
        ),
        border_style="green",
        padding=(1, 4),
    )
    console.print(interstitial, justify="center")
    time.sleep(INTERSTITIAL_HOLD_S)
    console.clear()

    _print_mode_banner(
        console,
        "MODE 2: WITH CYCLES (budget: $1.00)",
        border_style="green",
    )
    guarded = run_guarded(console)

    time.sleep(BUDGET_EXCEEDED_HOLD_S)
    console.clear()
    summary = DemoDisplay.build_summary_panel(
        unguarded_spend_usd=unguarded.spend_usd,
        unguarded_calls=unguarded.calls,
        unguarded_seconds=unguarded_elapsed,
        guarded_spend_usd=guarded.spend_usd,
        guarded_calls=guarded.calls,
    )
    console.print(summary)
    time.sleep(SUMMARY_HOLD_S)


if __name__ == "__main__":
    main()
