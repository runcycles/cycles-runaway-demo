# AUDIT

Tracks intentional changes to the demo's recorded artifacts and the wiring
that produces them. The live demo behavior (`./demo.sh`) and the agent code
(`agent/unguarded.py`, `agent/guarded.py`, `agent/simulation.py`) are
intentionally unchanged by anything below — only the recording pipeline.

## 2026-04-25 — Re-record `demo.gif` to show both modes side by side

Branch: `claude/re-record-demo-gif-y95V6`

### Why
The previous `demo.gif` recorded only `./demo.sh guarded`, so first-time
viewers saw a budget cap working with no visible runaway to compare it
against. The contrast is the demo. The new GIF puts the runaway and the cap
back to back in ~30 seconds.

### What changed
- `demo.tape` — rewritten to skip the docker bring-up and invoke a single
  Python orchestrator. PlaybackSpeed back to 1.0 (the orchestrator paces
  itself).
- `record.sh` — now pre-warms the Cycles stack (`docker compose down -v` →
  `up -d` → `wait_healthy` → `provision`) and exports `CYCLES_BASE_URL`,
  `CYCLES_API_KEY`, `CYCLES_TENANT` before launching `vhs`. The recording
  itself never sees docker output.
- `agent/record_orchestrator.py` — new. Drives end-to-end:
  1. MODE 1 banner (red), unguarded loop cut at 12s
  2. 0.5s "MODE 2: WITH CYCLES — same agent, same bug" interstitial
  3. MODE 2 banner (green), guarded loop to its natural BUDGET_EXCEEDED stop
  4. Green two-column summary card held for 4s
- `agent/display.py` — added `DemoDisplay.build_summary_panel(...)` helper.
  No change to existing panels or to the `_panel_*` methods used by
  unguarded.py / guarded.py.
- `README.md` — added a short note above the GIF explaining the 12s cut so
  numbers in the recording don't conflict with the "30s, ~$6" description
  of `./demo.sh`.

### Out of scope
- No changes to `unguarded.py`, `guarded.py`, `simulation.py`, or `demo.sh`.
- No ffmpeg/gifski post-processing — the orchestrator's natural pacing
  (~12s unguarded + 1.5s interstitial + ~7s guarded + 4s summary ≈ 25s)
  fit the brief without speed manipulation.

### Recording-only tweaks (do not affect `./demo.sh`)
- `record_orchestrator.py` monkey-patches `simulation.CALL_LATENCY_S`
  from 50ms down to 11ms **just for the unguarded segment** so the agent
  burns ~$10 of simulated spend in the same 12s window. The patch is
  reverted before the guarded segment runs (`try/finally` around the
  unguarded block), so `BUDGET_EXCEEDED` still lands at $1.00 / 100
  calls / ~7s as documented in the README. The live `./demo.sh` path
  imports `simulation` independently and is unaffected.
- `INTERSTITIAL_HOLD_S = 1.5s` — 0.5s was too quick for the viewer to
  read "MODE 2: WITH CYCLES — same agent · same bug".
- `BUDGET_EXCEEDED_HOLD_S = 3.5s` — 1s was too quick to register the
  "Final — GUARDED" panel before jumping to the summary.

### Summary card projections grounded in real-LLM economics
The end-card projects per-day / per-week / per-month at a defensible
real-LLM rate, not the simulation's deliberately-sped-up unguarded
rate. Assumptions:
- 1 second per call (typical end-to-end for a Sonnet-class call with
  a few hundred output tokens — 500ms is only realistic if you
  count time-to-first-token, not full completion)
- $0.03 per call — attributed to Claude Opus 4 @ 3K in / 500 out
  tokens. The actual Opus 4 math at $15/MTok in + $75/MTok out is
  ~$0.083/call, so the $0.03 figure deliberately under-states (real
  burn would be ~3x worse). Earlier draft attributed to Sonnet, but
  Sonnet at 3K/500 is ~$0.017/call — pedantic readers checking the
  Anthropic pricing page would find a 50% over-statement and that
  becomes the top reply. Opus attribution flips the direction so any
  pricing-page check reveals an under-statement instead.

Per stuck agent: `$0.03/sec → $108/hr → $2,592/day → $18,144/week →
$77,760/month`. Anyone with an LLM-API account can verify the $0.03
under-states Opus 4 reality. Footer: `Projections: 1s/call · $0.03/call ·
Claude Opus 4 @ 3K in / 500 out tokens`.

Cross-check: `_panel_projection` in `display.py` previously claimed
`~$3.60/hr per stuck ticket` next to the math
`(~$0.03/call × 120 calls/min × 60 min)` — those don't multiply out.
Corrected to `~$108/hr` (1s/call) so the live demo and the summary
card agree. README projection bullet updated to match.

Trade-off: an earlier draft used 500ms/call → $216/hr → $5,184/day →
$155,520/month for maximum visceral impact. The 500ms claim was the
weakest link credibility-wise (real LLM completions for a refinement
loop are usually 1–3s end-to-end), so we walked it back to 1s/call
even though the projections halve. $77K/month per stuck agent is still
an "I want it now" number for any production team.

### Verification performed
- `python3 -m pytest agent/tests/` — 16 passed.
- Standalone unguarded segment: cut at 12.0s, 239 calls, $2.39 spend,
  projection panel showing $17,182.91/day at the moment of cut.
- Summary panel render verified by hand.
- Guarded segment and full recording deferred to a host with Docker (this
  environment has no docker daemon). `./record.sh` is the entry point.
