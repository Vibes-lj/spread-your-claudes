# Budgeting: lane-budget / lane-guard / lane-cool

No backend here exposes a usage API, so spend is tracked **locally** and, since
it's easy to blow a shared account, **enforced** — a RED lane is refused, not
just discouraged.

## The ledger

Every wrapper call appends one JSON line to
`~/.local/share/claude-lanes/usage.jsonl`:

```json
{"ts":"2026-01-08T11:09:34Z","lane":"gemini","model":"gemini-flash-latest",
 "effort":"high","status":0,"dur_s":38,"tokens_in":null,"tokens_out":null,
 "rate_limited":false}
```

When a call comes back rate-limited (`quota exceeded`, `usage limit`,
`retry in Ns`, `try again at H:MM`, `429`, `RESOURCE_EXHAUSTED`), the wrapper
writes `cooldowns/<lane>` = epoch seconds until that lane is usable again.

## `lane-budget` — the picture

```
$ lane-budget
LANE      STATUS  WEIGHTED       RAW   WIN   FAIL  LAST    NOTE / REASON
codex     [RED]   3/10 (30.0%)   1     5h    1     4h      cooldown 2117s  COOLDOWN ~35m (until 14:52)
cursor    [grn]   4/300 (1.3%)   3     720h  1     2h      Monthly request quota, plan-dependent...
gemini    [grn]   7/200 (3.5%)   5     24h   3     4h      AI Studio free tier...
geminiweb [grn]   11/150 (7.3%)  7     5h    0     0s      Gemini WEB APP on a paid plan...
```

Reads the ledger + cooldowns + `~/.config/claude-lanes/budgets.json`. `--json`
for machines, `--since <hours>` to override the window.

### Weighted scoring

The verdict is scored on a **weighted** call count, not raw calls. Each call is
scaled by its `-e` level via `weight_by_effort` (top-level default map, per-lane
override):

| `-e` | default weight |
|---|---|
| `low` / none | 1 |
| `medium` | 2 |
| `high` | 3 |
| `ultra` | 5 |

So three `codex-think -e high` calls score **9** — over the RED line — even
though it's only 3 raw calls. `codex` overrides the map so even its *default*
effort counts 2.

### Verdict

For each lane: `yellow_pct` / `red_pct` are percentages of `soft_cap_calls`,
measured on the weighted score.

- **GREEN** — under the yellow line. Use freely by task fit.
- **YELLOW** — over yellow. Use only if this lane is the genuine best fit; else
  pick another.
- **RED** — over red, **or** an active cooldown, **or** a `min_spacing_secs`
  violation (last call too recent). Do not use unless nothing else can do the
  task — and say so.

## `lane-guard` — the gate

Every `*-think` wrapper calls `lane-guard <lane>` right before it hits the
backend:

- **exit 0** — clear (a YELLOW lane prints a warning and passes).
- **exit 3** — BLOCKED (RED / cooldown / spacing). The wrapper refuses.
- Fails **open** if `lane-budget` is missing or broken — a tooling bug never
  wedges delegation entirely.

Override for the genuine "only lane that can do this" case:

```
LANE_FORCE=1 codex-think -e high "…"
```

## `lane-cool` — the manual override

```
lane-cool codex 300      # park codex RED for 300 minutes
lane-cool codex clear    # lift it
lane-cool                # list active cooldowns
```

Use it the moment you *know* a backend is spent, before the auto-detector would
trip.

## Tuning `budgets.json`

The shipped caps are conservative guesses. Adjust to your real plans:

- `cursor.soft_cap_calls` — set from your Cursor dashboard's usage page, minus a
  buffer.
- `gemini.soft_cap_calls` — lower it if you start seeing 429s.
- `codex` — `soft_cap_calls`, `min_spacing_secs`, and `weight_by_effort` as the
  real limits of your account reveal themselves.
- `window_hours` — the rolling window per cap (gemini `24` ≈ daily RPD, codex
  `5` ≈ a rolling ChatGPT window, cursor `720` ≈ monthly).

Env overrides: `CLAUDE_LANES_CONFIG` (path to `budgets.json`),
`CLAUDE_LANES_DIR` (the ledger + cooldowns dir).
