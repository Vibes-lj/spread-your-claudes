#!/usr/bin/env bash
# Shared helpers for the research-lane wrappers (codex-think / gemini-think /
# cursor-think). Sourced, not executed. Records every lane call to a local
# ledger and maintains reactive cooldown markers when a backend rate-limits us.
# There is no usage API for any of these backends -- this is all local
# bookkeeping so `lane-budget` can give Claude a spend picture.

LANES_DIR="${CLAUDE_LANES_DIR:-$HOME/.local/share/claude-lanes}"
LANES_LEDGER="$LANES_DIR/usage.jsonl"
LANES_COOLDOWNS="$LANES_DIR/cooldowns"
mkdir -p "$LANES_COOLDOWNS" 2>/dev/null || true

# lane_scan_ratelimit <lane> <<< "$RAW"
# If the backend output signals a rate/quota limit, write a cooldown marker
# ("$LANES_COOLDOWNS/<lane>" = epoch seconds until which the lane is RED).
lane_scan_ratelimit() {
  local lane="$1" raw; raw="$(cat)"
  local now; now=$(date +%s)
  local until="" secs=""

  # "Please retry in 38.371s" / "try again in 42 seconds"
  secs="$(printf '%s\n' "$raw" | grep -oiE 'retry in ([0-9]+)' | grep -oE '[0-9]+' | head -1)"
  [ -z "$secs" ] && secs="$(printf '%s\n' "$raw" | grep -oiE 'try again in ([0-9]+) ?s' | grep -oE '[0-9]+' | head -1)"

  # "try again at 2:54 PM" -> today at that local time (tomorrow if already past)
  local hhmm ampm
  hhmm="$(printf '%s\n' "$raw" | grep -oiE 'try again at [0-9]{1,2}:[0-9]{2} ?(AM|PM)?' | grep -oiE '[0-9]{1,2}:[0-9]{2} ?(AM|PM)?' | head -1)"

  if [ -n "$secs" ]; then
    until=$(( now + secs ))
  elif [ -n "$hhmm" ]; then
    until="$(date -j -f '%I:%M %p' "$(echo "$hhmm" | tr 'a-z' 'A-Z' | sed 's/\([0-9]\)\([AP]M\)/\1 \2/')" +%s 2>/dev/null || true)"
    [ -n "$until" ] && [ "$until" -lt "$now" ] && until=$(( until + 86400 ))
  elif printf '%s\n' "$raw" | grep -qiE 'quota exceeded|usage limit|rate limit|RESOURCE_EXHAUSTED|429|too many requests'; then
    until=$(( now + 900 ))   # unknown duration -> 15 min default backoff
  fi

  if [ -n "$until" ]; then
    printf '%s\n' "$until" > "$LANES_COOLDOWNS/$lane"
    return 0
  fi
  return 1
}

# lane_record <lane> <model> <effort> <status> <dur_s> <tok_in> <tok_out>
# Appends one JSON line to the ledger. Empty numeric fields become null.
lane_record() {
  local lane="$1" model="$2" effort="${3:-}" status="${4:-}" dur="${5:-}" tin="${6:-}" tout="${7:-}"
  local rl=false
  [ -f "$LANES_COOLDOWNS/$lane" ] && [ "$(cat "$LANES_COOLDOWNS/$lane" 2>/dev/null || echo 0)" -gt "$(date +%s)" ] && rl=true
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local rp="${CLAUDE_LANES_DIR:-$HOME/.local/share/claude-lanes}/record.py"
  if [ -f "$rp" ]; then
    python3 "$rp" "$lane" "$model" "$effort" "$status" "$dur" "$tin" "$tout" "$ts" "$rl" "$LANES_LEDGER" 2>/dev/null \
      || printf '{"ts":"%s","lane":"%s","model":"%s","status":"%s"}\n' "$ts" "$lane" "$model" "$status" >> "$LANES_LEDGER"
  else
    printf '{"ts":"%s","lane":"%s","model":"%s","status":"%s"}\n' "$ts" "$lane" "$model" "$status" >> "$LANES_LEDGER"
  fi
}
