# cycles-runaway-demo

Shows the failure mode RunCycles prevents — and RunCycles preventing it.

Same agent. Same bug. Two modes.

## The scenario

A customer support bot drafts a response, evaluates its quality, and refines it in a loop until the quality score exceeds 8.0. The bug: the quality evaluator never returns above 6.9. Without a budget boundary, the agent loops forever — burning tokens with no exit condition. With RunCycles, the server returns `409 BUDGET_EXCEEDED` before the next call can proceed, and the agent stops cleanly.

## Run it

Prerequisites: Docker Compose v2+, Python 3.10+

```bash
git clone https://github.com/runcycles/cycles-runaway-demo
cd cycles-runaway-demo
pip install -r agent/requirements.txt
./demo.sh
```

Run a single mode:

```bash
./demo.sh unguarded    # without Cycles
./demo.sh guarded      # with Cycles
./demo.sh both         # both (default)
```

Stop the stack:

```bash
./teardown.sh
```

## What you'll see

### Without Cycles

The call counter climbs steadily — draft, evaluate, refine, evaluate, refine — with no exit condition. Budget thresholds ($0.10, $0.50, $1.00) are crossed one by one. The projection panel shows the hourly cost rate extrapolated from the simulation. After 30 seconds the demo auto-terminates, but in production there would be no hard stop. The final panel reads: *"In production: no hard stop existed. Alert fires AFTER spend."*

### With Cycles (budget: $1.00)

The same counter, the same loop, the same bug. But when cumulative spend reaches $1.00, the Cycles server returns `409 BUDGET_EXCEEDED` on the next reservation attempt. The `@cycles` decorator raises `BudgetExceededError`, the agent catches it, and the loop ends cleanly. The final panel reads: *"Cycles stopped the agent BEFORE call N+1 could proceed."*

## The code change

The diff between `agent/unguarded.py` and `agent/guarded.py` is exactly this:

```python
# --- Import the SDK ---
from runcycles import BudgetExceededError, CyclesClient, CyclesConfig, cycles, set_default_client

# --- Initialize the client ---
def _setup():
    config = CyclesConfig(
        base_url=os.environ["CYCLES_BASE_URL"],
        api_key=os.environ["CYCLES_API_KEY"],
        tenant=os.environ["CYCLES_TENANT"],
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

Rate limits cap velocity. Observability alerts fire after spend. Provider caps are per-provider. RunCycles stops the spend **BEFORE** the next call is made.

## Links

- Protocol: https://github.com/runcycles/cycles-protocol
- Server:   https://github.com/runcycles/cycles-server
- Python:   `pip install runcycles`
- Java:     `io.runcycles:cycles-client-java-spring`
- Node.js:  `npm install runcycles`
