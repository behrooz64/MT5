#!/usr/bin/env python3
"""Audit and summarize EMAMonitor V3.1 CSV exports.

Uses only Python's standard library. By default, CSV inputs are read from the
parent directory of this script (the TRX branch root). No source CSV is changed.
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

FILES = [
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Bars.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Events.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Outcomes.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Scenarios.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M5_Bars.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M5_Events.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M5_Outcomes.csv",
    "EMAMonitor_v3_1_XAUUSDb_PERIOD_M5_Scenarios.csv",
]

def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists() or path.stat().st_size == 0:
        return []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))

def number(value: Any) -> float | None:
    try:
        if value is None or str(value).strip() in ("", "NA", "N/A"):
            return None
        result = float(value)
        return result if result == result else None
    except (TypeError, ValueError):
        return None

def summarize_outcomes(rows: list[dict[str, str]]) -> dict[str, Any]:
    status = Counter(row.get("outcome_status", "") for row in rows)
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        groups[f'{row.get("event_type", "")}|{row.get("direction", "")}'].append(row)
    detail = {}
    for key, items in sorted(groups.items()):
        mfe = [v for row in items if (v := number(row.get("mfe_favourable_points"))) is not None]
        mae = [v for row in items if (v := number(row.get("mae_adverse_points"))) is not None]
        detail[key] = {
            "count": len(items),
            "status_counts": dict(Counter(x.get("outcome_status", "") for x in items)),
            "mean_mfe_points": round(statistics.mean(mfe), 2) if mfe else None,
            "mean_mae_points": round(statistics.mean(mae), 2) if mae else None,
        }
    return {"rows": len(rows), "status_counts": dict(status), "event_direction_groups": detail}

def summarize_scenarios(rows: list[dict[str, str]]) -> dict[str, Any]:
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        key = "|".join((row.get("scenario", ""), row.get("event_type", ""), row.get("direction", "")))
        groups[key].append(row)
    result = {}
    for key, items in sorted(groups.items()):
        nets = [v for row in items if (v := number(row.get("net_points"))) is not None]
        wins = [v for v in nets if v > 0]
        losses = [v for v in nets if v < 0]
        gross_win = sum(wins)
        gross_loss = -sum(losses)
        pf = gross_win / gross_loss if gross_loss else ("NO_LOSSES" if gross_win else None)
        result[key] = {
            "count": len(nets),
            "wins": len(wins),
            "losses": len(losses),
            "win_rate_percent": round(100 * len(wins) / len(nets), 2) if nets else None,
            "net_points": round(sum(nets), 2),
            "average_net_points": round(statistics.mean(nets), 2) if nets else None,
            "profit_factor": round(pf, 4) if isinstance(pf, float) else pf,
        }
    return {"rows": len(rows), "groups": result}

def summarize_bars(rows: list[dict[str, str]]) -> dict[str, Any]:
    if not rows:
        return {"rows": 0}
    spreads = [v for row in rows if (v := number(row.get("spread_points"))) is not None]
    times = []
    for row in rows:
        try:
            times.append(datetime.strptime(row.get("event_time", ""), "%Y.%m.%d %H:%M:%S"))
        except ValueError:
            pass
    gaps = [(b - a).total_seconds() / 60 for a, b in zip(times, times[1:])]
    return {
        "rows": len(rows),
        "first_bar": rows[0].get("event_time"),
        "last_bar": rows[-1].get("event_time"),
        "spread_points": {
            "count": len(spreads),
            "mean": round(statistics.mean(spreads), 4) if spreads else None,
            "median": statistics.median(spreads) if spreads else None,
            "min": min(spreads) if spreads else None,
            "max": max(spreads) if spreads else None,
        },
        "time_gaps_minutes": {
            "count": len(gaps),
            "median": statistics.median(gaps) if gaps else None,
            "max": max(gaps) if gaps else None,
        },
    }

def main() -> None:
    parser = argparse.ArgumentParser(description="Audit and summarize EMAMonitor V3.1 exports.")
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="Directory containing the original M1/M5 CSV exports (default: TRX root).")
    parser.add_argument("--json-out", type=Path, default=None,
                        help="Optional path for a JSON copy of the audit.")
    args = parser.parse_args()

    audit = {}
    loaded = {}
    for name in FILES:
        path = args.data_dir / name
        rows = read_csv(path)
        loaded[name] = rows
        audit[name] = {
            "exists": path.exists(),
            "bytes": path.stat().st_size if path.exists() else None,
            "data_rows": len(rows),
            "state": "MISSING" if not path.exists() else ("EMPTY" if path.stat().st_size == 0 else "POPULATED"),
        }

    report = {
        "analysis_script": Path(__file__).name,
        "data_directory": str(args.data_dir.resolve()),
        "file_audit": audit,
        "M1_bars": summarize_bars(loaded[FILES[0]]),
        "M1_outcomes": summarize_outcomes(loaded[FILES[2]]),
        "M1_scenarios": summarize_scenarios(loaded[FILES[3]]),
        "M5_bars": summarize_bars(loaded[FILES[4]]),
        "M5_outcomes": summarize_outcomes(loaded[FILES[6]]),
        "M5_scenarios": summarize_scenarios(loaded[FILES[7]]),
        "interpretation": [
            "Outcome MFE/MAE values are excursion measurements, not realized net profit.",
            "Scenario net_points is already gross_points minus estimated_cost_points; do not subtract the cost twice.",
            "A missing or empty CSV is reported as such and is never treated as a zero-performance result.",
            "M1/M5 filter joins must use only a fully completed M5 candle to avoid look-ahead bias.",
        ],
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    print(rendered)
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(rendered + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
