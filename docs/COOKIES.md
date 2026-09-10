# geminiweb-think: the unofficial lane

> **Read this before enabling `geminiweb-think`.**
>
> This lane does **not** use an official API. It uses
> [`gemini_webapi`](https://pypi.org/project/gemini-webapi/), a community
> reverse-engineered client, plus your browser's `gemini.google.com` session
> cookies, to drive the Gemini **web app** headlessly.
>
> - This may violate Google's Terms of Service. Your account is yours to risk.
> - Cookies can be invalidated by Google at any time; the lane just stops working.
> - The web app sometimes deflects a prompt it would happily answer over the API.
> - The other three lanes (`gemini-think`, `cursor-think`, `codex-think`) use
>   official, supported CLIs. If unofficial isn't for you, skip this one — the
>   system works fine with three lanes.

## Why bother

A paid Gemini plan (Google AI Pro / Ultra) raises limits on the **web app**, not
the **API**. They are separate products with separate billing. `gemini-think`
uses an API key on its own free tier; when that's drained, `geminiweb-think`
gives you a **completely separate quota pool** — plus the paid tier's top models
and Deep Research (`--deep`).

## Requirements

```
pip install gemini_webapi browser-cookie3
```

`gemini_webapi` pulls in `curl_cffi`. `browser-cookie3` is only needed for the
extraction step below, not at runtime.

## Extract the cookies

You need two cookies for the `.google.com` domain, from the browser profile
that is signed into your **paid** Gemini account (account index 0 in that
profile):

| cookie | required | notes |
|---|---|---|
| `__Secure-1PSID` | yes | the session id |
| `__Secure-1PSIDTS` | strongly recommended | rotates ~daily; the wrapper rewrites it in your env file after each call |

### Option A — `browser-cookie3` (scriptable)

Point it at the exact profile's cookie DB (Chrome shown; adjust for your
browser). On macOS this triggers a one-time "Chrome Safe Storage" keychain
prompt — allow it once.

```bash
python3 - <<'PY'
import browser_cookie3, json
# adjust the path to the profile signed into your paid Gemini account
COOKIE_DB = "~/Library/Application Support/Google/Chrome/Default/Cookies"
import os; COOKIE_DB = os.path.expanduser(COOKIE_DB)
cj = browser_cookie3.chrome(cookie_file=COOKIE_DB, domain_name="google.com")
want = {"__Secure-1PSID", "__Secure-1PSIDTS"}
print(json.dumps({c.name: c.value for c in cj if c.name in want}, indent=2))
PY
```

Chrome profiles live at `~/Library/Application Support/Google/Chrome/<Profile>/`
(macOS) or `~/.config/google-chrome/<Profile>/` (Linux). If you have several,
check each profile's `Preferences` file for the account email, or just try them.

### Option B — DevTools (manual)

1. Open `gemini.google.com`, signed into the paid account.
2. DevTools → Application → Cookies → `https://gemini.google.com`.
3. Copy the **Value** of `__Secure-1PSID` and `__Secure-1PSIDTS`.

## Store them

```bash
# ~/.config/secrets/gemini-web.env   (chmod 600)
GEMINI_WEB_1PSID=<value>
GEMINI_WEB_1PSIDTS=<value>
```

The installer creates this file empty for you. Never commit it — `.gitignore`
already excludes `secrets/*.env`.

## Test

```bash
geminiweb-think "reply with one word: PONG"
geminiweb-think -e high "a hard reasoning question"     # gemini-pro-advanced + extended thinking
geminiweb-think --deep "a research question"            # Deep Research (minutes)
```

## When it breaks

- **Auth errors / "cookie" / "1psid" in stderr** → your cookies expired or
  rotated. Re-extract both and update the env file.
- **"having a hard time fulfilling your request"** → the web app deflected. Try
  `-e high`, rephrase, or fall back to another lane.
- **`fetch failed` / connection errors inside a sandbox** → run the call
  un-sandboxed; `gemini.google.com` is usually not on an agent sandbox's
  network allowlist.
