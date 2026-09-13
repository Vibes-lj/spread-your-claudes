<div align="center">

# 🕸️ spread-your-claudes

### Stop paying the context tax.
**Fan your coding agent's big reads out across every AI CLI you already have.**

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![shell](https://img.shields.io/badge/bash%20%2B%20python3-stdlib%20only-black)](docs/ARCHITECTURE.md)
[![no daemon](https://img.shields.io/badge/no%20daemon-no%20ports-black)](#faq)
[![lanes](https://img.shields.io/badge/lanes-gemini%20%C2%B7%20cursor%20%C2%B7%20codex%20%C2%B7%20gemini--web-black)](#-the-lanes)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

</div>

---

## The problem

Coding agents like Claude Code re-send the **entire conversation** to the model on
every single turn. Read a 600-line file into the session and you keep paying for
those 600 lines on **every message after it** — until the session ends.

Long *"read a lot, then act"* sessions burn your usage limit on **carrying the
haystack**, not on thinking.

## The fix

`spread-your-claudes` is a handful of tiny CLI wrappers. Your agent hands the big
read to a **research lane** — a one-shot call to a *different* AI CLI (Gemini,
Cursor, Codex, a paid Gemini web plan) — which reads on **its** provider's quota
and returns a short, cited answer.

Your session grows by **5 lines** instead of **600**.

```
  YOU
   │
   ▼
┌────────────────────────────────┐        ← this box is your usage limit.
│  PRIMARY AGENT  (Claude Code)  │          everything in it is re-billed
│  owns the conversation         │          every turn.
│  decides · writes · commits    │
└───────────────┬────────────────┘
                │  "read this haystack. answer sharp. cite file:line."
                ▼
┌────────────────────────────────┐        ← this runs on the LANE's quota.
│  RESEARCH LANE (fire & return) │          it chews 600 lines of repo /
│  gemini · cursor · codex ·     │          logs / docs here — you don't
│  gemini-web                    │          pay for a byte of it.
└───────────────┬────────────────┘
                │  ~5 lines:  "auth.ts:42 — HMAC-SHA256, constant-time compare"
                ▼
        back into the primary agent's context  (+5 lines, not +600)
```

|  | Without | With a lane |
|---|---|---|
| Agent reads a 600-line file | +600 lines, **billed every turn after** | +5 lines, once |
| Whose quota did the reading | **yours** | the lane's |
| What comes back | the whole file | the answer + `file:line` |
| Who writes the code | your agent | your agent (unchanged) |

---

## How it works, in three steps

1. **Install** — `./install.sh` symlinks 8 wrappers into `~/.local/bin`. No network, no daemon, re-runnable.
2. **Set up one lane** — any single lane is useful on its own. `gemini-think` (free API tier) is the easiest.
3. **Let your agent delegate** — drop the CLAUDE.md snippet in and Claude reaches for a lane before a big read, picks one by fit, checks the budget, and reads back only the cited answer.

---

## 🛣️ The lanes

| Lane | Backend | Best at | Official? |
|---|---|---|---|
| **`gemini-think`** | Google Gemini CLI + AI Studio key | huge docs / log dumps / whole-repo sweeps · screenshots · high-volume cheap lookups | ✅ |
| **`cursor-think`** | Cursor Agent CLI | *"where in this codebase is X"* · code-aware Q&A · frontier second opinion · edit/run/commit | ✅ |
| **`codex-think`** | Codex CLI (ChatGPT account) | subtle root-cause · architecture tradeoffs · security reasoning | ✅ |
| **`geminiweb-think`** | Gemini **web app** on a paid plan, via cookies | a separate quota pool when the API key is drained · top models · `--deep` Research | ⚠️ unofficial — [read this](docs/COOKIES.md) |

Every lane takes the same flags:

```
<lane> [-C <dir>] [-e low|medium|high] [-m <model>] [-v] "<question>"
```

> `-C` point at a repo for context · `-e` effort (maps to a model per lane) · `-m` force a model · `-v` raw output

---

## ⚡ Quick start

```bash
git clone https://github.com/Vibes-lj/spread-your-claudes
cd spread-your-claudes
./install.sh
```

<sub>`install.sh` symlinks the wrappers into `~/.local/bin`, drops the budget engine into `~/.local/share/claude-lanes`, copies a starter `budgets.json` into `~/.config/claude-lanes`, and creates empty secret templates in `~/.config/secrets`. Re-runnable, never overwrites your config or secrets, never touches the network. `./install.sh --copy` copies instead of symlinking · `PREFIX=~/bin ./install.sh` targets another bin dir.</sub>

Then wire up **at least one** lane:

| Lane | Setup |
|---|---|
| `gemini-think` | `npm i -g @google/gemini-cli`, then put an [AI Studio key](https://aistudio.google.com/apikey) in `~/.config/secrets/gemini.env` |
| `cursor-think` | install `cursor-agent`, then `cursor-agent login` |
| `codex-think` | install the Codex CLI and sign in |
| `geminiweb-think` | optional / unofficial — [docs/COOKIES.md](docs/COOKIES.md) |

Smoke test and check your budget:

```bash
gemini-think "reply with one word: PONG"
lane-budget
```

Full per-lane instructions: **[docs/LANES.md](docs/LANES.md)**

---

## 🤖 Make your agent use it

```bash
cat claude/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md
cp -r claude/skills/delegate-mode claude/skills/lane-compare ~/.claude/skills/
```

- **CLAUDE.md snippet** — tells Claude to reach for a lane before a big read, pick by task fit, and run `lane-budget` first.
- **`delegate-mode` skill** — a persistent mode: the agent routes *all* big reads / analysis to lanes and keeps only deciding + writing.
- **`lane-compare` skill** — fan one question to every lane and synthesise the agreement / disagreement.

> Not on Claude Code? The wrappers are just CLIs — call them from any agent, script, or your shell.

---

## 📟 Usage

<details open>
<summary><b>One-off, by hand</b></summary>

```bash
# "where is X" in an unfamiliar repo — let Cursor's retrieval do the walking
cursor-think -C ~/src/bigapp "Where is request signing implemented, and what algorithm? Cite files."

# digest a huge changelog without pulling it into your session
gemini-think "Summarise the breaking changes in $(head -c 100000 CHANGELOG.md). Group by area."

# hard reasoning on a borrowed account — scarce, so -e high only when it counts
codex-think -C . -e high "Is the new lock-ordering in worker.rs deadlock-free? Walk the acquire order."

# API key drained? same provider, different quota pool
geminiweb-think -e high "Compare optimistic vs pessimistic locking for a booking system at 5% contention."
```
</details>

<details>
<summary><b>Cross-check when it matters</b></summary>

```bash
lane-compare -C . "Does this repo validate redirect targets against an allowlist? Cite the check."
```

Runs every lane in parallel, prints the answers side by side, and ends with a prompt
to synthesise where they agree, where they diverge, and what each lane caught that
the others missed.
</details>

<details>
<summary><b>Let the agent drive</b></summary>

With the CLAUDE.md snippet installed you just work normally — Claude reaches for a
lane when a task means reading a lot, picks one by fit, runs the budget gate, and
reads back only the cited answer. Say **"delegate mode"** to force it for a whole
session.
</details>

---

## 💰 Budgeting

No provider exposes a usage API, so spend is tracked in a local ledger — and
**enforced**:

```console
$ lane-budget
LANE      STATUS  WEIGHTED       RAW   WIN   FAIL  LAST    NOTE / REASON
codex     [RED]   3/10 (30.0%)   1     5h    1     4h      cooldown 2117s  COOLDOWN ~35m
cursor    [grn]   4/300 (1.3%)   3     720h  1     2h      Monthly request quota...
gemini    [grn]   7/200 (3.5%)   5     24h   3     4h      AI Studio free tier...
geminiweb [grn]   11/150 (7.3%)  7     5h    0     0s      Gemini web app on a paid plan...
```

- Each call is **weighted** by effort — `-e high` counts 3×, `ultra` 5×.
- **`grn`** use freely · **`YEL`** only if it's the best fit · **`RED`** only if nothing else can.
- Every wrapper calls `lane-guard` first and **refuses** a RED lane (`LANE_FORCE=1 <lane>` overrides).
- A rate-limited response auto-writes a **cooldown**. `lane-cool <lane> <mins>` sets one by hand.
- Tune the caps in `~/.config/claude-lanes/budgets.json` to your real plans.

Details: **[docs/BUDGETING.md](docs/BUDGETING.md)**

---

## 🎯 Use cases

- **Marathon debugging** — trace a bug across 20 files without carrying all 20 in context.
- **Onboarding an unfamiliar repo** — *"where does auth happen / what calls this / how does the job queue flow"*, answered with citations, none of it in your session.
- **Reviewing a big diff or design doc** — hand the doc to a lane, get the risks back in five lines.
- **Verifying a claim** — *"does this codebase actually validate X"* → `lane-compare`, cross-provider answer.
- **Stretching a subscription** — when your primary agent's limit is close, push the reading elsewhere.
- **Second opinion on an architecture call** — `lane-compare -e high` across Codex + Cursor + Gemini.
- **High-volume lookups** — dozens of small *"does this API exist / what's the signature"* on Gemini's cheap Flash quota.

---

## FAQ

<details>
<summary><b>Does this replace my coding agent?</b></summary>

No. It's a sidecar. Your agent still drives, decides, and does every write. Lanes
only read and answer.
</details>

<details>
<summary><b>Do I need all four lanes?</b></summary>

No. Start with one. `gemini-think` (free API tier) is the easiest and the cheap
workhorse.
</details>

<details>
<summary><b>Is my code sent to these providers?</b></summary>

Yes — a lane reads the repo / doc you point it at, on that provider's
infrastructure, exactly as using their CLI directly would. Point lanes only at code
you're comfortable sending there. Don't run lanes against secrets-bearing files.
</details>

<details>
<summary><b>Why is <code>geminiweb-think</code> flagged?</b></summary>

It uses an unofficial reverse-engineered client + your browser cookies. The other
three use official CLIs. It's optional; [docs/COOKIES.md](docs/COOKIES.md) has the
full disclaimer.
</details>

<details>
<summary><b>Does anything run as a server / daemon?</b></summary>

No. Every wrapper is a one-shot process. No ports, no background state — just a JSON
ledger file.
</details>

<details>
<summary><b>macOS only?</b></summary>

Developed on macOS. The wrappers are portable bash + python3; `lane-cool`'s `date -r`
and a couple of `date` calls are BSD-flavoured and may need `date -d` tweaks on
GNU/Linux. PRs welcome.
</details>

---

## Contributing

Issues and PRs welcome — especially: Linux `date` portability, more lanes (local
models, other CLIs), and better model-ID auto-detection. Keep wrappers
dependency-light (bash + python3 stdlib; `gemini_webapi` is the one exception, and
only for the optional lane).

## License

MIT — see [LICENSE](LICENSE).

---

<div align="center"><sub>

Not affiliated with Anthropic, Google, OpenAI, or Cursor.
"Claude", "Gemini", "Codex", "Cursor" are trademarks of their respective owners.
This project just calls their CLIs.

</sub></div>
