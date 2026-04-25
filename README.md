# Cycles Runaway Demo

A runaway agent burns $6 in 30 seconds. Cycles stops it at $1.

Same agent. Same bug. Two outcomes.

## The scenario

A customer support bot drafts a response, evaluates its quality, and refines it in a loop until the quality score exceeds 8.0. The bug: the quality evaluator never returns above 6.9. Without a budget boundary, the agent loops forever — burning tokens with no exit condition. With Cycles, the server returns `409 BUDGET_EXCEEDED` before the next call can proceed, and the agent stops cleanly.

No real LLM is used. All calls are simulated at 50ms latency. The cost math is real.

## Run it

Prerequisites: Docker Compose v2+, Python 3.10+, `curl`

```bash
git clone https://github.com/runcycles/cycles-runaway-demo
cd cycles-runaway-demo
python3 -m venv .venv && source .venv/bin/activate
pip install -r agent/requirements.txt
./demo.sh
```

That's it. The script starts the Cycles stack (Redis + server + admin), provisions a tenant and budget, then runs both modes back to back.

Run a single mode:

```bash
./demo.sh unguarded    # without Cycles (~30s)
./demo.sh guarded      # with Cycles (stops at $1.00)
./demo.sh both         # both back to back (default)
```

Re-runs just work — the script resets the stack automatically to ensure a fresh budget.

Stop the stack when done:

```bash
./teardown.sh
```

### Windows (WSL)

The demo runs on Windows 11 via WSL. Install [Docker Desktop for Windows](https://docs.docker.com/get-docker/) with the WSL 2 backend enabled (the default), then inside your WSL terminal:

```bash
sudo apt update && sudo apt install -y python3-full curl
git clone https://github.com/runcycles/cycles-runaway-demo
cd cycles-runaway-demo
python3 -m venv .venv && source .venv/bin/activate
pip install -r agent/requirements.txt
./demo.sh
```

Docker Desktop shares the daemon between Windows and WSL automatically — no extra configuration needed.

> **Note:** Ubuntu 23.04+ requires `python3-full` (not just `python3`) so that venvs get their own pip. Without it, even `pip` inside a venv hits the PEP 668 "externally-managed-environment" error.

### First run notes

The first run pulls three Docker images (~200MB total). You'll see Docker's pull progress. Subsequent runs start in seconds.

### Troubleshooting

**`JedisConnectionException: Failed to create socket` / `UnknownHostException: redis`**
You started the stack with `docker compose up` directly (instead of `./demo.sh`) on top of a previous run, and the `cycles-server` container ended up on a stale network where the `redis` service no longer exists. Reset and restart:

```bash
docker compose down -v && docker compose up -d
```

`./demo.sh` does this automatically before every run, so the script path doesn't hit this.

## What you'll see

![Cycles Runaway Demo](demo.gif)

The GIF squeezes a $10 vs $1 contrast into ~30 seconds: the unguarded
segment is recorded with simulation latency dropped to 11ms so spend hits
~$10 in 12s and the daily projection lights up at ~$75K/day. The live
demo (`./demo.sh`) keeps the documented 50ms latency — you'll see ~$6 of
unguarded spend over the full 30s instead.

### Without Cycles

A live terminal display (no scroll flood) shows three panels updating in-place:

- **Live Counter** — call count climbing, spend in dollars, current action with quality score
- **Budget Thresholds** — the $0.10 threshold crossed in red; $0.50 and $1.00 showing "X% to go"
- **Projection** — extrapolated cost rate: $/min, $/hr, $/day plus a real-LLM estimate (~$108/hr per stuck ticket at 1s × $0.03/call, conservative for Claude Opus 4)

After 30 seconds the demo auto-terminates. The final red panel reads:
> *"In production: no hard stop existed. Alert fires AFTER spend."*

In 30s at simulation speed, the agent makes ~600 calls and spends ~$6.00. The projection panel shows what happens if you don't catch it — the hourly and daily rates are the scary numbers.

### With Cycles (budget: $1.00)

The same counter, the same loop, the same bug. The display is identical — same panels, same structure. But when cumulative spend reaches $1.00 (after ~100 calls), the Cycles server returns `409 BUDGET_EXCEEDED` on the next reservation attempt. The `@cycles` decorator raises `BudgetExceededError`, the agent catches it, and the loop ends cleanly. The final green panel reads:
> *"Cycles stopped the agent BEFORE call N+1 could proceed."*

### Expected output

```
⚡ Cycles — Runaway Agent Demo

Resetting stack (clean budget state)...

  [Docker compose output]

Waiting for services to be healthy...
Provisioning tenant and budget...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MODE 1: Without Cycles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [live panels update in-place for ~30s]

╭──────────────── Final — UNGUARDED ─────────────────╮
│ Result:   auto-stop after 30s                      │
│ Calls:    ~595                                     │
│ Spend:    ~$5.95                                   │
│ Duration: 30.0s                                    │
│                                                    │
│ In production: no hard stop existed.               │
│ Alert fires AFTER spend.                           │
╰────────────────────────────────────────────────────╯

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MODE 2: With Cycles (budget: $1.00)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [live panels update in-place until budget hit]

╭───────────────── Final — GUARDED ──────────────────╮
│ Result:   BUDGET_EXCEEDED — Cycles server          │
│           returned 409                             │
│ Calls:    100                                      │
│ Spend:    $1.0000                                  │
│ Duration: ~8s                                      │
│                                                    │
│ Cycles stopped the agent BEFORE call 101           │
│ could proceed.                                     │
╰────────────────────────────────────────────────────╯

Demo complete.
  Swagger UI:   http://localhost:7878/swagger-ui.html
  Admin UI:     http://localhost:7979/swagger-ui.html
  Re-run:       ./demo.sh
  Stop stack:   ./teardown.sh
```

## The code change

The diff between `agent/unguarded.py` and `agent/guarded.py` is:

```python
# --- Import the SDK ---
from runcycles import BudgetExceededError, CyclesClient, CyclesConfig, cycles, set_default_client

# --- Initialize the client ---
def _setup():
    config = CyclesConfig(
        base_url=os.environ["CYCLES_BASE_URL"],
        api_key=os.environ["CYCLES_API_KEY"],
        tenant=os.environ["CYCLES_TENANT"],
        workspace="default",
        app="default",
        workflow="default",
        agent="support-bot",
    )
    set_default_client(CyclesClient(config))

# --- Add three decorators ---
@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="draft-response")
def draft_response(ticket_text: str) -> str: ...

@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="evaluate-quality")
def evaluate_quality(draft: str) -> float: ...

@cycles(estimate=COST_PER_CALL_MICROCENTS, action_kind="llm.completion", action_name="refine-response")
def refine_response(draft: str, score: float) -> str: ...

# --- Catch the budget exception ---
except BudgetExceededError:
    # agent stops cleanly
```

Three decorators. One except. That is the entire integration.

## Why this matters

Rate limits cap velocity, not total exposure. Observability alerts fire after the damage. Provider caps are per-provider and per-key. Cycles enforces a hard ceiling **before** the next call is made — across providers, tenants, and agents.

## Next steps

After running the demo, explore how to add Cycles to your own application:

- [What is Cycles?](https://runcycles.io/quickstart/what-is-cycles) — understand the problem and the solution
- [End-to-End Tutorial](https://runcycles.io/quickstart/end-to-end-tutorial) — zero to a working budget-guarded app in 10 minutes
- [Choose a First Rollout](https://runcycles.io/quickstart/how-to-choose-a-first-cycles-rollout-tenant-budgets-run-budgets-or-model-call-guardrails) — decide your adoption strategy
- [Adding Cycles to an Existing App](https://runcycles.io/how-to/adding-cycles-to-an-existing-application) — incremental adoption guide
- [Full Documentation](https://runcycles.io) — complete docs at runcycles.io

## Links

- Protocol: https://github.com/runcycles/cycles-protocol
- Server:   https://github.com/runcycles/cycles-server
- Python:   `pip install runcycles`
- Java:     `io.runcycles:cycles-client-java-spring`
- Node.js:  `npm install runcycles`
