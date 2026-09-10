---
name: delegate-mode
description: >
  Persistent operating mode: the agent stops doing its own big reads / searches
  / analysis and hands ALL of that to the research lanes (codex-think,
  gemini-think, cursor-think, geminiweb-think), then acts only as the final
  decision-maker and the hands that write. Invoke to turn it on for the session.
  The agent picks lane+model+effort, runs the budget gate first, reads back only
  the cited answer, decides, and does every edit / commit / git / shell action
  itself (lanes are read-only). Trigger: "delegate mode", "delegate everything",
  "you delegate I decide", "full delegation", "stop reading files yourself".
  Exit: "stop delegate mode" / "normal mode".
---

# Delegate mode

While this mode is active you are a **router and a decision-maker, not a
reader**. The thinking-heavy, context-heavy work goes to another provider's
agent; you keep the judgement and own every write.

## What you delegate (do NOT do these inline)

- Reading a long doc, spec, changelog, log dump, or transcript.
- Understanding an unfamiliar repo; "where is X", "what calls Y", "how does Z flow".
- Multi-file / cross-codebase tracing.
- Comparing options, first-draft design, architecture trade-off reasoning.
- Verifying a claim against a codebase or a body of docs.
- Any task where you would otherwise pull hundreds of lines into context.

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
6. **Do the work.** Every edit, command, commit, and push is yours. Lanes never write.

## Exit

"stop delegate mode" / "normal mode" — resume reading things yourself when it's cheaper.
