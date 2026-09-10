#!/usr/bin/env python3
"""Render the research-lane spend picture.

Usage: budget.py <config_json> <ledger_jsonl> <cooldowns_dir> <want_json:0|1> <since_hours_or_empty>

Spend is scored two ways:
  * raw calls   -- how many wrapper calls landed in the rolling window
  * weighted    -- each call scaled by effort (a `-e high` codex call costs more
                   of a borrowed account than a `-e low` lookup). weight_by_effort
                   comes from the lane block, falling back to the top-level map,
                   falling back to 1.
Verdict (GREEN/YELLOW/RED) is driven by the WEIGHTED score vs yellow_pct/red_pct
of soft_cap_calls, plus: any active cooldown marker, and any `min_spacing_secs`
violation (last call too recent) -> RED with a reason.
"""
import json, os, sys, time, datetime

cfg_path, ledger_path, cooldowns_dir, want_json, since_override = sys.argv[1:6]
want_json = want_json == "1"
now = time.time()

try:
    cfg = json.load(open(cfg_path))
    lanes_cfg = cfg.get("lanes", {})
except Exception as e:
    print(f"lane-budget: cannot read {cfg_path}: {e}", file=sys.stderr)
    sys.exit(1)

top_weights = cfg.get("weight_by_effort", {}) or {}

rows = []
if os.path.exists(ledger_path):
    for line in open(ledger_path):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            pass

def parse_ts(s):
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=datetime.timezone.utc).timestamp()
    except Exception:
        return 0.0

def weight_for(effort, wmap):
    key = (effort or "default")
    if key in wmap:
        return float(wmap[key])
    return float(wmap.get("default", 1))

out = {}
for lane, c in lanes_cfg.items():
    win_h = float(since_override) if since_override else float(c.get("window_hours", 24))
    cap = int(c.get("soft_cap_calls", 0)) or 1
    yellow = cap * float(c.get("yellow_pct", 60)) / 100.0
    red = cap * float(c.get("red_pct", 85)) / 100.0
    wmap = c.get("weight_by_effort", top_weights) or {}
    min_spacing = float(c.get("min_spacing_secs", 0) or 0)
    cutoff = now - win_h * 3600

    lane_rows = [r for r in rows if r.get("lane") == lane and parse_ts(r.get("ts", "")) >= cutoff]
    n = len(lane_rows)
    weighted = sum(weight_for(r.get("effort"), wmap) for r in lane_rows)
    fails = sum(1 for r in lane_rows if r.get("status") not in (0, None))
    tin = sum(r.get("tokens_in") or 0 for r in lane_rows)
    tout = sum(r.get("tokens_out") or 0 for r in lane_rows)

    all_lane_ts = [parse_ts(r.get("ts", "")) for r in rows if r.get("lane") == lane]
    last_ts = max(all_lane_ts) if all_lane_ts else 0
    secs_since_last = int(now - last_ts) if last_ts else None

    cd_path = os.path.join(cooldowns_dir, lane)
    cd_until = 0
    if os.path.exists(cd_path):
        try:
            cd_until = int(open(cd_path).read().strip())
        except Exception:
            cd_until = 0
    cooling = cd_until > now

    spacing_block = bool(min_spacing and last_ts and (now - last_ts) < min_spacing)

    if cooling:
        verdict, reason = "RED", f"cooldown {int(cd_until - now)}s"
    elif spacing_block:
        verdict, reason = "RED", f"min spacing {int(min_spacing - (now - last_ts))}s to go"
    elif weighted >= red:
        verdict, reason = "RED", f"weighted {weighted:g}/{cap} >= red"
    elif weighted >= yellow:
        verdict, reason = "YELLOW", f"weighted {weighted:g}/{cap} >= yellow"
    else:
        verdict, reason = "GREEN", ""

    out[lane] = {
        "verdict": verdict,
        "reason": reason,
        "calls": n,
        "weighted": round(weighted, 1),
        "soft_cap": cap,
        "window_hours": win_h,
        "pct": round(100.0 * weighted / cap, 1),
        "failures_in_window": fails,
        "tokens_in": tin,
        "tokens_out": tout,
        "min_spacing_secs": int(min_spacing),
        "secs_since_last_call": secs_since_last,
        "cooldown_until": (datetime.datetime.fromtimestamp(cd_until).strftime("%Y-%m-%d %H:%M")
                           if cooling else None),
        "cooldown_secs_left": (int(cd_until - now) if cooling else 0),
        "note": c.get("note", ""),
    }

if want_json:
    print(json.dumps(out, indent=2))
    sys.exit(0)

order = {"RED": 0, "YELLOW": 1, "GREEN": 2}
icon = {"RED": "[RED]", "YELLOW": "[YEL]", "GREEN": "[grn]"}
print(f"{'LANE':<9} {'STATUS':<7} {'WEIGHTED':<13} {'RAW':<5} {'WIN':<5} {'FAIL':<5} {'LAST':<7} NOTE / REASON")
for lane in sorted(out, key=lambda l: (order[out[l]['verdict']], l)):
    d = out[lane]
    w = f"{d['weighted']:g}/{d['soft_cap']} ({d['pct']}%)"
    win = f"{int(d['window_hours'])}h"
    last = "-" if d["secs_since_last_call"] is None else (
        f"{d['secs_since_last_call']}s" if d["secs_since_last_call"] < 3600
        else f"{d['secs_since_last_call'] // 3600}h")
    tail = d["reason"] or d["note"][:52]
    extra = ""
    if d["cooldown_until"]:
        extra = f"  COOLDOWN ~{d['cooldown_secs_left'] // 60}m (until {d['cooldown_until']})"
    print(f"{lane:<9} {icon[d['verdict']]:<7} {w:<13} {d['calls']:<5} {win:<5} {d['failures_in_window']:<5} {last:<7} {tail}{extra}")

if not (os.path.exists(ledger_path) and os.path.getsize(ledger_path) > 0):
    print("\n(ledger empty - no lane calls recorded yet)")
