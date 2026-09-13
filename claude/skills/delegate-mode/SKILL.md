---
name: delegate-mode
description: >
  Persistent operating mode: the agent stops doing big reads, searches, and
  self-contained subtasks itself and hands them to lanes (codex-think,
  gemini-think, cursor-think, geminiweb-think) — which can read, edit, run
  commands, and commit, not just research — then the agent reviews what comes
  back, decides, and handles anything a lane can't (push/deploy, its own
  tools/credentials/browser). Invoke to turn it on for the session. The agent
  picks lane+model+effort, runs the budget gate first, and reads back only the
  cited answer or result. Trigger: "delegate mode", "delegate everything",
  "you delegate I decide", "full delegation", "stop reading files yourself".
  Exit: "stop delegate mode" / "normal mode".
---

# Delegate mode

While this mode is active you are a **router and a decision-maker, not a
reader or a doer**. The thinking-heavy, context-heavy work — and self-contained
subtasks — go to another provider's agent; you keep the judgement, review what
comes back, and do anything a lane can't (push, deploy, your own
tools/credentials/browser).

## What you delegate (do NOT do these inline)

- Reading a long doc, spec, changelog, log dump, or transcript.
- Understanding an unfamiliar repo; "where is X", "what calls Y", "how does Z flow".
- Multi-file / cross-codebase tracing.
- Comparing options, first-draft design, architecture trade-off reasoning.
- Verifying a claim against a codebase or a body of docs.
- Any task where you would otherwise pull hundreds of lines into context.
- A self-contained subtask — mostly read/edit/run/commit inside one repo —
  that doesn't need your own browser, MCP connectors, or credentials to
  finish. Hand it the whole task, not just the reading part.

Hand it to a lane with the shared interface:

```
codex-think     [-C dir] [-e low|medium|high] [-m model] "<question>"
gemini-think    [-C dir] [-e low|medium|high] [-m model] "<question>"
cursor-think    [-C dir] [-e low|medium|high] [-m model] "<question>"
geminiweb-think [-C dir] [-e low|medium|high] [-m model] [--deep] "<question>"
```

Ask a **sharp, self-contained question** and request `file:line` evidence. Read
back only the answer — never re-pull the haystack the lane just chewed.

## What you still do yourself

1. **Pick the lane** by task fit:
   gemini = huge context / cheap / high volume / multimodal;
   cursor = codebase retrieval, "where is X", frontier second opinion;
   codex = subtle root-cause / security / hard multi-step (scarce account — last resort);
   geminiweb = when gemini-think is drained, or you want the top model / `--deep`.
2. **Pick the smallest `-e`** that will get it right; step up only for genuinely hard tasks.
3. **Run the budget gate first:** `lane-budget`. GREEN = free choice; YELLOW =
   only if that lane is the genuine best fit; RED / cooldown = do not use unless
   nothing else can. The wrappers enforce this via `lane-guard` and will refuse
   a RED lane (override: `LANE_FORCE=1 …`, sparingly).
4. **Cross-check when the answer matters:** `lane-compare "<question>"` (see the
   `lane-compare` skill) instead of trusting one lane.
5. **Decide.** Synthesise the lane answer(s), resolve conflicts, choose the approach.
6. **Push, deploy, and anything a lane can't.** `git push`, anything that
   leaves the machine, and anything needing your own credentials or browser —
   yours only. A lane can read, edit, run, and commit inside the repo you hand
   it; publishing stays here.

## Exit

"stop delegate mode" / "normal mode" — resume reading things yourself when it's cheaper.
