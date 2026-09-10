---
name: lane-compare
description: >
  Send ONE prompt to all four research lanes at once (codex-think, gemini-think,
  cursor-think, geminiweb-think), collect their answers in parallel, and lay them
  side by side so they can be compared. Use when an answer matters enough to want
  a cross-provider check, when one lane's answer looks wrong or hand-wavy, or for
  an architecture / security / correctness call. The agent then writes the
  agreement / disagreement synthesis. Trigger: "compare lanes", "ask all of
  them", "cross-check the providers", "second opinion on this".
---

# lane-compare

Fan one question out to every lane, wait for all, compare. Backs the
"answer really matters -> two lanes, different providers" rule.

## Run it

```
lane-compare [-C dir] [-e low|medium|high] [-m model] [--json] [--lanes codex,gemini,cursor,geminiweb] "<question>"
```

- `-C dir` — repo context, passed to every wrapper. Omit for a repo-less question.
- `-e` — effort, passed to every wrapper (each maps it to its own model).
- `--lanes` — subset / reorder, e.g. `--lanes gemini,cursor` to skip a RED lane.
- `--json` — machine object instead of the text report.
- Each lane runs in parallel; each logs itself to the usage ledger; each is read-only.

Ask a **sharp, self-contained question** and request `file:line` evidence — the
lanes don't share your context.

## Before running

Run `lane-budget`. This fires one call per lane at once. If a lane is
RED / cooldown, drop it with `--lanes` rather than letting `lane-guard` fail it
mid-run (the other lanes still return; the report marks the skipped one FAILED).
`gemini` and `geminiweb` are the same provider but **different quota pools** —
keeping both is fine, and useful when the API key is drained.

## After running — synthesise

The script only lays the answers out; it does not decide. Then write:

1. **Agreement** — points all responding lanes make. Treat as high confidence.
2. **Divergence** — where they disagree. Name it, say which is likely right and
   **why** (evidence quality, known lane strengths, `file:line` that checks out).
3. **Unique** — anything one lane raised that the others missed (often the most
   useful part).
4. **Answer** — the single synthesised conclusion you're acting on, and any
   residual uncertainty.

Present it as a short table or four labelled sections — something scannable.

## When NOT to use it

- Routine lookups — one lane (usually `gemini-think`) is enough and far cheaper.
- When `lane-budget` shows most lanes YELLOW/RED — do a single call on a GREEN
  one instead and save the budget.
