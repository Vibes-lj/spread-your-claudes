# How it works

## The problem: context is a tax you pay every turn

An agent like Claude Code re-sends the **entire conversation** to the model on
every single turn. Read a 600-line file into the session and you don't pay for
those 600 lines once — you pay for them again on every message that follows,
until the session ends or gets compacted.

Long "read a lot, then act" sessions burn through usage limits this way. The
expensive part isn't the thinking, it's carrying the haystack.

## The fix: read it somewhere you don't pay for

A **research lane** is a one-shot call to a *different* AI CLI that you already
have access to (Gemini, Cursor, a ChatGPT/Codex account, a paid Gemini web
plan). The lane does the big read on **its** provider's quota and returns a
short, cited answer. Your session grows by five lines instead of six hundred.

```
                 ┌─────────────────────────────────────────┐
   you  ───────▶ │  primary agent (Claude Code)            │
                 │  - keeps the conversation               │
                 │  - makes decisions                      │
                 │  - does every write / commit / command  │
                 └───────────────┬─────────────────────────┘
                                 │  "read this haystack, answer sharply"
                 ┌───────────────▼─────────────────────────┐
                 │  a research lane  (fire-and-return)      │
                 │  gemini-think / cursor-think /           │
                 │  codex-think / geminiweb-think           │
                 │  - reads the repo / doc / logs          │
                 │  - burns THAT provider's tokens         │
                 │  - prints ONLY the final answer         │
                 └─────────────────────────────────────────┘
                                 │  ~5 cited lines
                                 ▼
                    back into the primary agent's context
```

## Design rules

1. **Fire-and-return.** Each `*-think` wrapper runs the backend CLI once,
   strips the banner / tool-call transcript / progress chatter, and prints only
   the final answer to stdout. Failures go to stderr with the decisive line
   first. No interactive session, no state.

2. **Read-only by convention.** Every wrapper prepends a prompt telling the lane
   it is a research tool with no write access — do not edit, commit, or push.
   `cursor-think` also passes `--mode ask`, which is structurally read-only. The
   primary agent does 100% of the writes. Lanes are eyes, not hands.

3. **Uniform interface.** Every lane takes the same flags:
   `-C <dir>` (repo context), `-e low|medium|high` (effort → model), `-m <model>`
   (override), `-v` (raw output). So the calling agent picks a lane by task fit
   without relearning an interface.

4. **One shared ledger.** No provider exposes a usage API, so each call appends
   a line to `usage.jsonl` (timestamp, lane, model, effort, exit status,
   duration, tokens where available). `lane-budget` reads that ledger against
   soft caps you set; `lane-guard` (called by every wrapper) enforces the
   verdict — a RED lane is **refused**, not merely discouraged.

5. **Dynamic selection.** There is no default lane and no default effort. The
   calling agent picks the lane whose strengths fit the task and the smallest
   effort that will get it right, and steps up only when the task is genuinely
   hard. See [LANES.md](LANES.md).

## What's in the box

| Path | Role |
|---|---|
| `bin/gemini-think` `bin/cursor-think` `bin/codex-think` `bin/geminiweb-think` | the four lanes |
| `bin/lane-compare` | fan one question to all lanes, print answers side by side |
| `bin/lane-budget` | GREEN / YELLOW / RED spend picture from the local ledger |
| `bin/lane-guard` | preflight gate every wrapper calls; refuses a RED lane |
| `bin/lane-cool` | manually park a lane RED when you know it's spent |
| `lib/lib.sh` | shared bash helpers: ledger append + rate-limit → cooldown |
| `lib/budget.py` `lib/record.py` | the weighted-scoring engine and ledger writer |
| `config/budgets.example.json` | starter soft caps — tune to your real plans |
| `claude/` | a CLAUDE.md snippet + two skills to make Claude Code use all this |

## Failure behaviour

- A lane that rate-limits writes a **cooldown marker** (`cooldowns/<lane>` =
  epoch until clear). `lane-budget` reports it; `lane-guard` refuses the lane
  until it expires.
- `lane-guard` **fails open**: if `lane-budget` is missing or broken, the call
  proceeds rather than wedging delegation over a tooling bug.
- `lane-compare` runs every lane in parallel and never aborts the batch — a
  failed lane is marked `FAILED` in the report; the others still return.
