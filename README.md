# spread-your-claudes

**Stop paying the context tax. Spread your agent's big reads across every AI CLI you already have.**

Coding agents like Claude Code re-send the **whole conversation** to the model
on every turn. Read a 600-line file into the session and you keep paying for
those 600 lines on every message after — until the session ends. Long
"read a lot, then act" sessions burn your usage limit on *carrying the
haystack*, not on thinking.

`spread-your-claudes` is a set of tiny CLI wrappers that fix this. Your agent
hands the big read to a **research lane** — a one-shot call to a *different* AI
CLI (Gemini, Cursor, Codex, a paid Gemini web plan) — which does the reading on
**its** provider's quota and returns a short, cited answer. Your session grows
by five lines instead of six hundred.

```
                 ┌────────────────────────────────────────┐
   you  ───────▶ │  primary agent (e.g. Claude Code)      │
                 │  keeps the conversation • decides •    │
                 │  does every write / commit / command   │
                 └──────────────┬─────────────────────────┘
                                │  "read this haystack, answer sharply, cite it"
                 ┌──────────────▼─────────────────────────┐
                 │  a research lane  (fire-and-return)    │
                 │  gemini-think · cursor-think ·         │
                 │  codex-think · geminiweb-think         │
                 │  reads the repo/doc/logs on THAT       │
                 │  provider's tokens → prints the answer │
                 └──────────────┬─────────────────────────┘
                                │  ~5 cited lines
                                ▼
                   back into the primary agent's context
```

- **Your Claude limit lasts longer** — the expensive read happened somewhere you don't pay for.
- **Four independent quota pools** — when one provider is drained, route to another.
- **Cited answers only** — every lane is told to give `file:line` evidence and lead with the answer.
- **Read-only by convention** — lanes are eyes, not hands. Your primary agent does 100% of the writes.
- **Budget-aware** — a local ledger + `lane-budget` / `lane-guard` stop you blowing a shared account.

---

## The lanes

| Lane | Backend | Best at | Official? |
|---|---|---|---|
| **gemini-think** | Google Gemini CLI + AI Studio key | huge docs / log dumps / whole-repo sweeps, screenshots, high-volume cheap lookups | ✅ |
| **cursor-think** | Cursor Agent CLI (`--mode ask`) | "where in this codebase is X", code-aware Q&A, frontier second opinion | ✅ |
| **codex-think** | Codex CLI (ChatGPT account) | subtle root-cause, architecture tradeoff, security reasoning | ✅ |
| **geminiweb-think** | Gemini **web app** on a paid plan, via cookies | a separate quota pool when the API key is drained; top models + Deep Research | ⚠️ unofficial — [read this](docs/COOKIES.md) |

You only need the lanes you'll use. **Any single lane is useful on its own.**

All four take the same flags:

```
<wrapper> [-C <dir>] [-e low|medium|high] [-m <model>] [-v] "<question>"
```

`-C` a repo for context · `-e` effort (maps to a model per lane) · `-m` force a model · `-v` raw output.

---

## Quick start

```bash
git clone https://github.com/<you>/spread-your-claudes
cd spread-your-claudes
./install.sh
```

`install.sh` symlinks the wrappers into `~/.local/bin`, drops the budget engine
into `~/.local/share/claude-lanes`, copies a starter `budgets.json` into
`~/.config/claude-lanes`, and creates empty secret templates in
`~/.config/secrets`. It is re-runnable and never overwrites your config or
secrets. Nothing in it contacts a network. (`./install.sh --copy` copies the
scripts instead of symlinking; `PREFIX=~/bin ./install.sh` targets a different
bin dir.)

Then set up at least one lane:

| Lane | Setup |
|---|---|
| `gemini-think` | `npm i -g @google/gemini-cli`, then put an [AI Studio key](https://aistudio.google.com/apikey) in `~/.config/secrets/gemini.env` |
| `cursor-think` | install `cursor-agent`, then `cursor-agent login` |
| `codex-think` | install the Codex CLI and sign in |
| `geminiweb-think` | optional/unofficial — [docs/COOKIES.md](docs/COOKIES.md) |

Smoke test and check your budget:

```bash
gemini-think "reply with one word: PONG"
lane-budget
```

Full per-lane instructions: **[docs/LANES.md](docs/LANES.md)**.

---

## Make your agent use it

Copy the Claude Code integration:

```bash
cat claude/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md
cp -r claude/skills/delegate-mode claude/skills/lane-compare ~/.claude/skills/
```

- The **CLAUDE.md snippet** tells Claude to reach for a lane before a big read,
  pick the lane by task fit, and run `lane-budget` first.
- **`delegate-mode`** skill — a persistent mode where the agent routes *all*
  big reads/analysis to lanes and keeps only deciding + writing.
- **`lane-compare`** skill — fan one question to every lane and synthesise the
  agreement / disagreement.

Not using Claude Code? The wrappers are just CLIs — call them from any agent,
script, or your own shell.

---

## Usage

### One-off, by hand

```bash
# "where is X" in an unfamiliar repo — let Cursor's retrieval do the walking
cursor-think -C ~/src/bigapp "Where is the request signing implemented, and what algorithm? Cite files."

# digest a huge changelog without pulling it into your session
gemini-think "Summarise the breaking changes in $(cat CHANGELOG.md | head -c 100000). Group by area."

# hard reasoning on a borrowed account — scarce, so -e high only when it counts
codex-think -C . -e high "Is the new lock-ordering in worker.rs deadlock-free? Walk the acquire order."

# API key drained? same provider, different quota pool
geminiweb-think -e high "Compare optimistic vs pessimistic locking for a booking system under 5% contention."
```

### Cross-check when it matters

```bash
lane-compare -C . "Does this repo validate redirect targets against an allowlist? Cite the check."
```

Runs every lane in parallel, prints the answers side by side, and ends with a
prompt to synthesise where they agree, where they diverge, and what each lane
caught that the others missed.

### Let the agent drive

With the CLAUDE.md snippet installed, you just work normally — Claude reaches for
a lane when a task means reading a lot, picks one by fit, runs the budget gate,
and reads back only the cited answer. Say **"delegate mode"** to force it for a
whole session.

---

## Budgeting

No provider exposes a usage API, so spend is tracked in a local ledger and
**enforced**:

```
$ lane-budget
LANE      STATUS  WEIGHTED       RAW   WIN   FAIL  LAST    NOTE / REASON
codex     [RED]   3/10 (30.0%)   1     5h    1     4h      cooldown 2117s  COOLDOWN ~35m
cursor    [grn]   4/300 (1.3%)   3     720h  1     2h      Monthly request quota...
gemini    [grn]   7/200 (3.5%)   5     24h   3     4h      AI Studio free tier...
geminiweb [grn]   11/150 (7.3%)  7     5h    0     0s      Gemini web app on a paid plan...
```

- Each call is **weighted** by effort (`-e high` counts 3×, `ultra` 5×).
- **GREEN** use freely · **YELLOW** only if it's the best fit · **RED** only if
  nothing else can — and every wrapper calls `lane-guard` first and **refuses**
  a RED lane (`LANE_FORCE=1 <wrapper>` overrides).
- A rate-limited response auto-writes a **cooldown**. `lane-cool <lane> <mins>`
  sets one by hand when you know a backend is spent.
- Tune the caps in `~/.config/claude-lanes/budgets.json` to your real plans.

Details: **[docs/BUDGETING.md](docs/BUDGETING.md)**.

---

## Use cases

- **Marathon debugging** — trace a bug across 20 files without carrying all 20 in context.
- **Onboarding an unfamiliar repo** — "where does auth happen / what calls this / how does the job queue flow", answered with citations, none of it in your session.
- **Reviewing a big diff or design doc** — hand the doc to a lane, get the risks back in five lines.
- **Verifying a claim** — "does this codebase actually validate X" → `lane-compare`, get a cross-provider answer.
- **Stretching a subscription** — when your primary agent's limit is close, push the reading elsewhere.
- **Second opinion on an architecture call** — `lane-compare -e high` across Codex + Cursor + Gemini.
- **High-volume lookups** — dozens of small "does this API exist / what's the signature" questions on Gemini's cheap Flash quota.

---

## FAQ

**Does this replace my coding agent?** No. It's a sidecar. Your agent still
drives, decides, and does every write. Lanes only read and answer.

**Do I need all four lanes?** No. Start with one. `gemini-think` (free API tier)
is the easiest and the cheap workhorse.

**Is my code sent to these providers?** Yes — a lane reads the repo/doc you
point it at, on that provider's infrastructure, same as using their CLI
directly. Point lanes only at code you're comfortable sending there. Don't run
lanes against secrets-bearing files.

**Why is `geminiweb-think` flagged?** It uses an unofficial reverse-engineered
client + your browser cookies. The other three use official CLIs. It's optional;
[docs/COOKIES.md](docs/COOKIES.md) has the full disclaimer.

**Does anything run as a server / daemon?** No. Every wrapper is a one-shot
process. No ports, no background state — just a JSON ledger file.

**macOS only?** Developed on macOS. The wrappers are portable bash + python3;
`lane-cool`'s `date -r` and a couple of `date` invocations are BSD-flavoured and
may need `date -d` tweaks on GNU/Linux. PRs welcome.

---

## Contributing

Issues and PRs welcome — especially: Linux `date` portability, more lanes
(local models, other CLIs), and better model-ID auto-detection. Keep wrappers
dependency-light (bash + python3 stdlib; `gemini_webapi` is the one exception,
and only for the optional lane).

## License

MIT — see [LICENSE](LICENSE).

---

*Not affiliated with Anthropic, Google, OpenAI, or Cursor. "Claude", "Gemini",
"Codex", "Cursor" are trademarks of their respective owners. This project just
calls their CLIs.*
