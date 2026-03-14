"""
Rich-based live terminal display for the runaway agent demo.
Used by both unguarded.py and guarded.py.
Renders in-place using rich.live.Live (no scroll flood).
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Optional

from rich.console import Console, Group
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from simulation import QUALITY_THRESHOLD


# Budget thresholds to track (microcents, label)
THRESHOLDS = [
    (10_000_000, "$0.10"),
    (50_000_000, "$0.50"),
    (100_000_000, "$1.00"),
]

BUDGET_MICROCENTS = 100_000_000  # $1.00
MICROCENTS_PER_USD = 100_000_000


@dataclass
class DemoState:
    mode: str  # "UNGUARDED" or "GUARDED"
    ticket: str
    calls: int = 0
    spend_microcents: int = 0
    start_time: float = field(default_factory=time.monotonic)
    last_action: str = "starting..."
    last_score: Optional[float] = None
    threshold_crossed: dict[int, tuple[int, float]] = field(default_factory=dict)
    stopped: bool = False
    stop_reason: str = ""

    def record_call(self, cost_microcents: int, action: str, score: float | None = None) -> None:
        self.calls += 1
        self.spend_microcents += cost_microcents
        self.last_action = action
        if score is not None:
            self.last_score = score
        # Record threshold crossings
        for threshold_mc, _ in THRESHOLDS:
            if threshold_mc not in self.threshold_crossed and self.spend_microcents >= threshold_mc:
                self.threshold_crossed[threshold_mc] = (self.calls, time.monotonic())

    @property
    def elapsed(self) -> float:
        return time.monotonic() - self.start_time

    @property
    def spend_usd(self) -> float:
        return self.spend_microcents / MICROCENTS_PER_USD

    @property
    def calls_per_second(self) -> float:
        e = self.elapsed
        return self.calls / e if e > 0 else 0.0

    @property
    def usd_per_minute(self) -> float:
        e = self.elapsed
        return (self.spend_usd / e * 60) if e > 0 else 0.0


class DemoDisplay:
    """Context manager wrapping rich.live.Live. Refreshes at 10 fps."""

    def __init__(self, state: DemoState) -> None:
        self.state = state
        self.console = Console()
        self.live = Live(
            self._build_layout(),
            console=self.console,
            refresh_per_second=10,
            transient=True,
        )

    def __enter__(self) -> "DemoDisplay":
        self.live.__enter__()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        # If exiting due to an unhandled exception, record it
        if exc_type is not None and not self.state.stopped:
            self.state.stopped = True
            self.state.stop_reason = f"unexpected error: {exc_val}"
        # Render final summary before exiting Live
        self.live.update(self._build_layout())
        self.live.__exit__(exc_type, exc_val, exc_tb)
        # Print final summary panel (persistent)
        self.console.print(self._build_final_panel())
        return None

    def refresh(self) -> None:
        self.live.update(self._build_layout())

    def _build_layout(self) -> Group:
        return Group(
            self._panel_live_counter(),
            self._panel_thresholds(),
            self._panel_projection(),
        )

    def _mode_style(self) -> str:
        return "red" if self.state.mode == "UNGUARDED" else "green"

    def _panel_live_counter(self) -> Panel:
        s = self.state
        style = self._mode_style()

        t = Table.grid(padding=(0, 2))
        t.add_column(justify="right", style="bold")
        t.add_column()

        t.add_row("Mode", Text(s.mode, style=f"bold {style}"))
        t.add_row("Ticket", s.ticket)
        t.add_row("Calls", f"{s.calls:,}")

        if s.mode == "GUARDED":
            pct = s.spend_microcents / BUDGET_MICROCENTS * 100
            spend_text = f"${s.spend_usd:.4f}  ({pct:.1f}% of $1.00 budget)"
        else:
            spend_text = f"${s.spend_usd:.4f}"
        t.add_row("Spend", spend_text)

        t.add_row("Elapsed", f"{s.elapsed:.1f}s")

        action_text = s.last_action
        if s.last_score is not None:
            action_text += f"  (score: {s.last_score:.1f} / {QUALITY_THRESHOLD:.1f})"
        t.add_row("Last action", action_text)

        return Panel(t, title="[bold]Live Counter[/bold]", border_style=style)

    def _panel_thresholds(self) -> Panel:
        s = self.state
        style = self._mode_style()

        t = Table.grid(padding=(0, 2))
        t.add_column(justify="right", style="bold", min_width=8)
        t.add_column()

        for threshold_mc, label in THRESHOLDS:
            if threshold_mc in s.threshold_crossed:
                call_num, crossed_time = s.threshold_crossed[threshold_mc]
                ago = time.monotonic() - crossed_time
                t.add_row(
                    Text(label, style="red bold"),
                    Text(f"✓ passed at call {call_num} ({ago:.1f}s ago)", style="red"),
                )
            else:
                if s.spend_microcents > 0:
                    pct_to_go = (1 - s.spend_microcents / threshold_mc) * 100
                    pct_to_go = max(0, pct_to_go)
                    t.add_row(
                        Text(label, style="dim"),
                        Text(f"{pct_to_go:.0f}% to go", style="dim"),
                    )
                else:
                    t.add_row(Text(label, style="dim"), Text("100% to go", style="dim"))

        # Bottom row
        t.add_row("", "")
        if s.mode == "UNGUARDED":
            t.add_row("", Text("$∞ No hard stop.", style="red bold"))
        else:
            t.add_row("", Text("$1.00 Hard stop — BUDGET_EXCEEDED raised at this limit", style="green bold"))

        return Panel(t, title="[bold]Budget Thresholds[/bold]", border_style=style)

    def _panel_projection(self) -> Panel:
        s = self.state
        style = self._mode_style()

        lines: list[Text] = []

        if s.elapsed < 2.0:
            lines.append(Text("Calculating...", style="dim italic"))
        else:
            rate_min = s.usd_per_minute
            rate_hr = rate_min * 60
            rate_day = rate_hr * 24

            lines.append(Text(f"Sim rate:  ${rate_min:.2f}/min → ${rate_hr:.2f}/hr → ${rate_day:.2f}/day"))
            lines.append(Text(""))
            lines.append(Text(
                "Real LLM (500ms/call): ~$3.60/hr per stuck ticket",
                style="dim",
            ))
            lines.append(Text(
                "  (~$0.03/call × 120 calls/min × 60 min)",
                style="dim",
            ))
            lines.append(Text(""))

            if s.mode == "UNGUARDED":
                lines.append(Text("Ctrl+C to stop", style="red bold"))
            else:
                lines.append(Text("Cycles enforces $1.00 hard stop", style="green bold"))

        return Panel(
            Group(*lines),
            title="[bold]Projection[/bold]",
            border_style=style,
        )

    def _build_final_panel(self) -> Panel:
        s = self.state
        style = self._mode_style()

        lines: list[Text] = []
        lines.append(Text(f"Result:   {s.stop_reason}", style=f"bold {style}"))
        lines.append(Text(f"Calls:    {s.calls:,}"))
        lines.append(Text(f"Spend:    ${s.spend_usd:.4f}"))
        lines.append(Text(f"Duration: {s.elapsed:.1f}s"))
        lines.append(Text(""))

        if s.mode == "UNGUARDED":
            lines.append(Text(
                "In production: no hard stop existed. Alert fires AFTER spend.",
                style="red bold",
            ))
        elif "BUDGET_EXCEEDED" in s.stop_reason:
            lines.append(Text(
                f"Cycles stopped the agent BEFORE call {s.calls + 1} could proceed.",
                style="green bold",
            ))
        elif "error" in s.stop_reason.lower():
            lines.append(Text(
                "Agent stopped due to an error — see message above.",
                style="yellow bold",
            ))
        else:
            lines.append(Text(
                f"Cycles stopped the agent BEFORE call {s.calls + 1} could proceed.",
                style="green bold",
            ))

        return Panel(
            Group(*lines),
            title=f"[bold]Final — {s.mode}[/bold]",
            border_style=style,
        )
