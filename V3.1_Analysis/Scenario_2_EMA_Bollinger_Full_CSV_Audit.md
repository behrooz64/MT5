# Scenario 2 - Full CSV Audit and EMA/Bollinger Simulation
Date: 2026-10-31
Repository: behrooz64/MT5
Branch: TRX
Reference collector: EMAMonitor_v3_1.mq5
Symbol: XAUUSDb

## Executive result

The previous pre-check was incorrect: M1 data files are populated in the TRX branch. This report supersedes that preliminary finding without deleting or modifying it.

All 18 CSV files in the branch were inventoried. M1 and M5 contain substantial observations; H1 files contain headers only. The Events CSV files have a data-format defect in the final `details` field: 1,058 M1 rows and 180 M5 rows contain unescaped commas in that field. Numeric and preceding columns remain positionally recoverable by treating the remainder of each row as the final details field.

A custom, time-aligned Scenario 2 simulation was run using:
- M5 trend: last fully closed M5 close versus its EMA200.
- M1 setup: candle range touches EMA100, then closes in the trend direction beyond EMA100 with matching candle body.
- Bollinger filters compared separately: close on the trend side of the middle band; outer-band re-entry; both filters.
- Entry: signal M1 close.
- Fixed TP/SL: 300 / 300 points, matching V3.1 defaults.
- Cost: 30 points, matching `InpSimCostPoints`.
- Maximum holding window: 120 M1 bars, matching `InpSimMaxBars`.
- Conservative intrabar rule: if TP and SL are both touched in one bar, SL is counted first.
- M5 alignment: only the latest M5 candle already closed by the M1 signal close was used.

This is a preliminary research simulation, not a deployable strategy or proof of out-of-sample profitability. Signals are independently simulated and can overlap; the drawdown sequence therefore is not an account-level portfolio drawdown.

## 1. Inventory of all CSV files

| Timeframe | File | Data rows |
|---|---|---:|
| H1 | Bars | 0 |
| H1 | Events | 0 |
| H1 | Outcomes | 0 |
| H1 | PendingState | 0 |
| H1 | ScenarioState_v3 | 0 |
| H1 | Scenarios | 0 |
| M1 | Bars | 6,323 |
| M1 | Events | 20,733 |
| M1 | Outcomes | 13,251 |
| M1 | PendingState | 66 |
| M1 | ScenarioState_v3 | 182 |
| M1 | Scenarios | 82,182 |
| M5 | Bars | 1,267 |
| M5 | Events | 4,385 |
| M5 | Outcomes | 2,796 |
| M5 | PendingState | 96 |
| M5 | ScenarioState_v3 | 192 |
| M5 | Scenarios | 17,196 |

M1 Bars window: 2026-10-23 23:54 to 2026-10-30 13:31.
M5 Bars window: 2026-10-23 23:50 to 2026-10-30 13:25.

Bars CSVs have 59 columns, Events 36, Outcomes 15, PendingState 10, ScenarioState_v3 46, and Scenarios 18. All non-Events CSV rows have the expected number of comma-separated fields. Events have the unescaped-comma issue described above. H1 has no observations yet.

## 2. Custom Scenario 2 results

| Setup | Signals | Win rate | Net points | Profit factor |
|---|---:|---:|---:|---:|
| EMA100 touch + M5 EMA200 trend + candle confirmation | 255 | 56.9% | +2,850 | 1.08 |
| Above + close on correct side of BB middle | 146 | 57.5% | +2,220 | 1.11 |
| Above + outer-band re-entry | 33 | 48.5% | -1,290 | 0.77 |
| Above + BB middle and outer-band re-entry | 9 | 66.7% | +630 | 1.64 |

Direction split for the BB-middle version:
- BUY: 54 signals, 51.9% wins, -1,020 net points, PF 0.88.
- SELL: 92 signals, 60.9% wins, +3,240 net points, PF 1.27.

The outer-band re-entry filter reduces the sample sharply and is negative overall. The combined strict filter has only nine trades; its PF is not statistically persuasive.

## 3. Stability check

Using 2026-10-27 00:00 as a simple chronological split for the BB-middle version:
- Earlier segment: 34 signals, 58.8% win rate, +780 points, PF 1.17.
- Later segment: 112 signals, 57.1% win rate, +1,440 points, PF 1.09.

The SELL-side result is the stronger candidate for further testing. BUY-side results are negative under the BB-middle filter. This is not enough data to conclude that SELL is robust; the later segment is still only a few days.

## 4. What the collector's existing signals actually mean

The source code confirms that the existing `EMA_TREND_PULLBACK_BUY/SELL` events are based on EMA15 touch, EMA stack, and candle confirmation, not EMA100 touch. Therefore they are not the same as the custom Scenario 2 tested above.

Existing M1 V3.1 simulation rows for those native events:
- EMA trend pullback BUY, FIXED_TP_SL: 271 trades, 48.7% win rate, -10,230 net points, PF 0.78.
- EMA trend pullback SELL, FIXED_TP_SL: 378 scenario rows, 51.6% win rate, -7,740 net points, PF 0.87.
- Bollinger re-entry BUY, FIXED_TP_SL: 434 rows, 51.6% win rate, -8,820 net points, PF 0.87.
- Bollinger re-entry SELL, FIXED_TP_SL: 382 rows, 45.3% win rate, -22,260 net points, PF 0.68.

These native event results do not validate the custom M5 EMA200 + M1 EMA100 combination; they are separate baselines.

## 5. Data-quality findings and limitations

1. H1 files are header-only and cannot support H1 analysis yet.
2. M1 Events has 1,058 rows and M5 Events has 180 rows where the final `details` text contains unescaped commas. This violates strict CSV field-count expectations and should be fixed in the collector by ensuring CSV-safe field writing/quoting.
3. M1/M5 PendingState and ScenarioState_v3 are snapshots of still-open observation/simulation tracks, not completed trades.
4. M1/M5 bars cover about seven calendar days but not necessarily continuous market minutes.
5. This is one symbol and one short sample. No parameter optimization should be treated as validated.
6. The custom test uses overlapping independent signals. Portfolio position limits, signal de-duplication/cooldown, execution slippage beyond the fixed 30-point cost, and account-level exposure have not been modeled.
7. M5 trend is joined using only a candle that had closed by the M1 signal close, avoiding future-bar leakage.

## 6. Research recommendation

Do not deploy Scenario 2 yet. Keep the M5 EMA200 + M1 EMA100 structure as the next candidate, but focus the next controlled test on:
- SELL-only with the BB middle-side filter;
- BUY as a separate experiment rather than combining it with SELL;
- a non-overlapping signal policy and account-level drawdown;
- a longer fresh forward sample, then a final untouched out-of-sample window.

Do not use the nine-trade strict BB filter as the selected strategy. Its sample is too small.

## 7. Change control

This is a research report only. No EA source, trading logic, or raw CSV file was changed. No other branch was changed.
