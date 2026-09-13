# The lanes

All four share one interface:

```
<wrapper> [-C <dir>] [-e low|medium|high] [-m <model>] [-v] "<question>"
```

- `-C <dir>` — a repo to use as context. Omit for a repo-less question (cheaper;
  `codex-think` in particular re-reads the repo's `AGENTS.md` every call).
- `-e` — effort. Maps to a concrete backend model per lane (table below). `-m`
  always overrides.
- `-v` — raw backend output, for debugging the wrapper.
- Output is the final answer only. Failures print the decisive line to stderr.

## Which lane for what

| Task shape | Lane | Why |
|---|---|---|
| Digest a huge doc / long log dump / whole-repo sweep; screenshots & PDFs; high-volume cheap lookups | **gemini-think** | biggest context window, fastest, cheapest, highest free daily quota |
| "Where in this codebase is X", code-aware Q&A, plan a change, want a frontier GPT / Claude opinion, or an actual edit/run/commit task | **cursor-think** | built-in codebase retrieval/indexing; routes to frontier models |
| Subtle bug root-cause, architecture tradeoff, security reasoning, careful multi-step design on one repo | **codex-think** | strongest deliberate reasoning, tunable effort; but rate-limits fast and re-reads `AGENTS.md` every call |
| `gemini-think` (API) is drained; want a top-model or Deep Research answer from knowledge + reasoning (no repo traversal) | **geminiweb-think** | Gemini web app on a paid plan — a **separate quota pool** from the API key; unofficial, see [COOKIES.md](COOKIES.md) |
| The answer really matters | **`lane-compare`** — two+ lanes, different providers | a cheap cross-check catches a confident wrong answer |

## Effort → model

`-m` always overrides. Model IDs drift as providers ship new versions —
re-check with the provider's own `models` command and edit the `case` block in
the wrapper if a name is rejected. Gemini's `*-latest` aliases self-heal.

| `-e` | codex-think | gemini-think | cursor-think | geminiweb-think | use for |
|---|---|---|---|---|---|
| `low` | reasoning effort = low | `gemini-flash-lite-latest` | `composer-2.5` | `gemini-flash` | factual lookup, "does X exist", verify one claim |
| *(none)* | config default | `gemini-flash-latest` | `auto` | `gemini-pro` | normal research, summarise a doc |
| `medium` | reasoning effort = medium | `gemini-flash-latest` | `claude-sonnet-…-thinking-high` | `gemini-pro` | compare options, first-draft design, code-aware Q&A |
| `high` | reasoning effort = high | `gemini-flash-latest`¹ | `claude-opus-…-thinking-high` | `gemini-pro-advanced` + extended thinking | architecture tradeoff, subtle root-cause, hard multi-step |

¹ The free Gemini **API** tier is Flash-only. For genuinely hard reasoning route
to `codex-think -e high`, `cursor-think -e high`, or `geminiweb-think -e high`
on a paid web plan. `codex-think` also accepts `-e ultra` — its own most
expensive tier; reserve it for genuinely exotic reasoning.

## Set up each lane

You only need the lanes you'll use. Any one lane is useful on its own.

### gemini-think  (official CLI, free tier)
1. Install the Gemini CLI: `npm i -g @google/gemini-cli` (or your package manager).
2. Get an AI Studio key: https://aistudio.google.com/apikey
3. Put it in `~/.config/secrets/gemini.env` (chmod 600):
   `GEMINI_API_KEY=...`
4. Test: `gemini-think "reply with one word: PONG"`

This key's free tier is **separate** from any Gemini web-app subscription — it's
its own quota, its own billing.

### cursor-think  (official CLI, uses your Cursor plan)
1. Install the Cursor Agent CLI (`cursor-agent`).
2. `cursor-agent login` (shares the session with the Cursor desktop app).
   - If you run agents in a sandbox that can't read the macOS keychain, put a
     `CURSOR_API_KEY` in `~/.config/secrets/cursor.env` instead.
3. Confirm model IDs: `cursor-agent models` — fix the wrapper's `case` block if needed.
4. Test: `cursor-think "reply with one word: PONG"`

### codex-think  (official CLI, uses a ChatGPT/Codex account)
1. Install the Codex CLI and sign in (`codex` reads `~/.codex/auth.json`).
2. Optionally set a default `model_reasoning_effort` in `~/.codex/config.toml`.
3. Test: `codex-think "reply with one word: PONG"`

Codex rate-limits the fastest of the four and re-reads the repo's `AGENTS.md`
every call — the budget config treats it as the scarce lane by default.

### geminiweb-think  (UNOFFICIAL — optional)
Uses a reverse-engineered client (`gemini_webapi`) and your browser session
cookies to talk to `gemini.google.com`. This may violate Google's Terms of
Service — only you can decide if that's acceptable for your account. The upside
is a quota pool completely separate from the API key, plus the paid tier's top
models and Deep Research.

Full walkthrough: **[COOKIES.md](COOKIES.md)**.
