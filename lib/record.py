#!/usr/bin/env python3
"""Append one call record to the research-lane ledger.
Usage: record.py <lane> <model> <effort> <status> <dur_s> <tok_in> <tok_out> <ts_iso> <rate_limited> <ledger_path>
Empty numeric args become null. Never raises: on any error it writes a minimal line.
"""
import json, sys

def num(x):
    try:
        return int(x)
    except Exception:
        try:
            return float(x)
        except Exception:
            return None

try:
    lane, model, effort, status, dur, tin, tout, ts, rl, path = sys.argv[1:11]
    rec = {
        "ts": ts, "lane": lane, "model": model or None, "effort": effort or None,
        "status": num(status), "dur_s": num(dur),
        "tokens_in": num(tin), "tokens_out": num(tout),
        "rate_limited": rl == "true",
    }
    with open(path, "a") as f:
        f.write(json.dumps(rec) + "\n")
except Exception:
    try:
        with open(sys.argv[10], "a") as f:
            f.write(json.dumps({"ts": sys.argv[8], "lane": sys.argv[1],
                                "model": sys.argv[2], "status": sys.argv[4]}) + "\n")
    except Exception:
        pass
