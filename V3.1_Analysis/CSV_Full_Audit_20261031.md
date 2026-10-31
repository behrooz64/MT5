# V3.1 | Full CSV Audit and Scenario 2 Recheck
Date: 2026-10-31
Repository: behrooz64/MT5
Branch: TRX
Reference EA: EMAMonitor_v3_1.mq5
Reference EA blob: 9c10fc76bf907ef18e5b84c2a0fdc0e66a4010ab

## 1. Correction to the previous pre-check

The previous report stated that the M1 CSV files were zero-byte files. That conclusion came from a file-content fetch returning an empty payload. The branch tree and Git blob reads confirm that the M1 CSV files are populated. The previous "M1 data missing" conclusion was incorrect and is superseded by this audit.

All 18 CSV files in the TRX root were read from their Git blobs. No CSV source file was changed.

## 2. Complete CSV inventory

| Timeframe | File | Data rows |
|---|---|---:|
| M1 | Bars | 6,323 |
| M1 | Events | 20,733 |
| M1 | Outcomes | 13,251 |
| M1 | Scenarios | 82,182 |
| M1 | PendingState | 66 |
| M1 | ScenarioState_v3 | 182 |
| M5 | Bars | 1,267 |
| M5 | Events | 4,385 |
| M5 | Outcomes | 2,796 |
| M5 | Scenarios | 17,196 |
| M5 | PendingState | 96 |
| M5 | ScenarioState_v3 | 192 |
| H1 | Bars | 0 |
| H1 | Events | 0 |
| H1 | Outcomes | 0 |
| H1 | Scenarios | 0 |
| H1 | PendingState | 0 |
| H1 | ScenarioState_v3 | 0 |

M1 + M5 contain 148,669 data rows. (Corrected arithmetic: M1 122,737 + M5 25,932.) H1 files contain headers only; no H1 observations are available.

## 3. Collection window and data continuity

- M1 Bars: 2026-10-23 23:54:00 through 2026-10-30 13:31:00; 6,323 rows.
- M5 Bars: 2026-10-23 23:50:00 through 2026-10-30 13:25:00; 1,267 rows.
- M1 median interval: 1 minute. Largest interval: 2,887 minutes.
- M5 median interval: 5 minutes. Largest interval: 2,890 minutes.
- There are several gaps longer than the expected bar interval. The largest gap is likely a market closure or collection interruption; it must not be treated as continuous price history.
- Mean spread: M1 12.68 points; M5 12.32 points. Both observed spread ranges are 12–16 points.
- Recorded tick size: 0.01. Point-based results are specific to this XAUUSDb export and its recorded quote specification.

## 4. Integrity checks

| Check | M1 | M5 |
|---|---:|---:|
| Duplicate bar timestamps | 0 | 0 |
| Duplicate event IDs | 0 | 0 |
| Outcomes without a matching event ID | 0 | 0 |
| Scenarios without a matching event ID | 0 | 0 |
| Outcome rows marked COMPLETE | 13,251 / 13,251 | 2,796 / 2,796 |

The PendingState and ScenarioState_v3 files contain in-progress tracking state. They are not completed outcomes and must not be added to completed-trade counts.

## 5. Existing V3.1 scenario simulation results

These are aggregate results across multiple different event types, not one unified strategy. They are useful for auditing the existing simulator but should not be used as a standalone strategy ranking.

| Simulation | M1 rows | M1 net points | M1 PF | M5 rows | M5 net points | M5 PF |
|---|---:|---:|---:|---:|---:|---:|
| FIXED_TP_SL | 9,171 | -223,150 | 0.85 | 1,946 | -55,380 | 0.83 |
| ATR_TP_SL | 9,173 | -236,306.8 | 0.77 | 1,945 | -13,894.3 | 0.97 |
| ATR_TP_TRAIL | 9,173 | -296,716.9 | 0.64 | 1,946 | -18,971.9 | 0.95 |
| ATR_BREAK_EVEN | 9,173 | -271,540.1 | 0.71 | 1,946 | -13,912.5 | 0.97 |
| FIXED_RR_2R | 9,162 | -241,989 | 0.88 | 1,945 | -24,450 | 0.94 |
| GRID_AVERAGING_SIM | 9,170 | +371,265 | 1.61 | 1,945 | +55,725 | 1.37 |
| PYRAMIDING_SIM | 9,169 | -374,008 | 0.71 | 1,945 | -57,450 | 0.78 |
| MONEY_RISK_1_5R | 9,000 | -458,283 | 0.89 | 1,820 | -392,427 | 0.80 |
| PERCENT_RISK_1_5R | 8,991 | -214,458 | 0.95 | 1,758 | -67,884 | 0.96 |

The grid simulation's positive aggregate is not proof of a tradable edge. The source simulation uses simplified equal-size adds and does not fully model portfolio margin, liquidation, execution quality, or all broker-specific costs. The rows also combine many different signal families.

V3.1 source assumptions confirmed from the EA:
- Bollinger period 20, deviation 2.0, applied price Close.
- Fixed TP / SL: 300 / 300 points.
- ATR TP / SL multiples: 1.5 / 1.0.
- Trailing distance: 1.0 ATR.
- Maximum scenario duration: 120 bars.
- Estimated scenario cost: 30 points, subtracted once.

## 6. Scenario 2 definition and method

Scenario 2 was rechecked using actual M1 and M5 Bars data.

Entry conditions:
1. M1 candle touches EMA100.
2. BUY: M1 low touches/breaks the lower Bollinger band and the same M1 candle closes back above the lower band.
3. SELL: M1 high touches/breaks the upper Bollinger band and the same M1 candle closes back below the upper band.
4. Trend filter uses only the most recent fully closed M5 candle available at the M1 signal close.
5. Two M5 trend definitions were tested separately:
   - EMA200 side: M5 close above EMA200 for BUY; below EMA200 for SELL.
   - Full EMA stack: EMA50 > EMA100 > EMA200 for BUY; reverse stack for SELL.
6. Optional candle confirmation: bullish M1 body for BUY; bearish M1 body for SELL.

Simulation:
- Entry at signal M1 close.
- Fixed TP 300 points and SL 300 points.
- SL is given priority if TP and SL are both touched in one candle.
- Maximum 120 subsequent M1 bars.
- Flat estimated cost of 30 points deducted once.
- The test uses the actual M1 OHLC sequence after each signal. It is a historical OHLC simulation, not a tick-level execution replay.

## 7. Scenario 2 results

### M5 EMA200-side filter

| Direction | Candle confirmation | Signals | Wins | Win rate | Net points | PF |
|---|---|---:|---:|---:|---:|---:|
| BUY | No | 23 | 11 | 47.8% | -990 | 0.75 |
| SELL | No | 45 | 16 | 35.6% | -5,250 | 0.45 |
| BUY | Yes | 13 | 7 | 53.8% | -90 | 0.95 |
| SELL | Yes | 28 | 10 | 35.7% | -3,240 | 0.45 |

### M5 full EMA-stack filter

| Direction | Candle confirmation | Signals | Wins | Win rate | Net points | PF |
|---|---|---:|---:|---:|---:|---:|
| BUY | No | 14 | 5 | 35.7% | -1,620 | 0.45 |
| SELL | No | 36 | 10 | 27.8% | -5,880 | 0.31 |
| BUY | Yes | 8 | 3 | 37.5% | -840 | 0.49 |
| SELL | Yes | 21 | 6 | 28.6% | -3,330 | 0.33 |

All trades in these small subsets exited by TP or SL within the tested horizon; none required the time exit.

## 8. Interpretation

1. Under this exact same-candle EMA100-touch + Bollinger-reentry definition, the sample is small: 23 BUY / 45 SELL with the EMA200-side filter, and 14 BUY / 36 SELL with the full-stack filter.
2. The SELL side is weak in both filters, with PF 0.45 or lower.
3. BUY with EMA200-side and bullish-candle confirmation is closest to break-even (13 samples, PF 0.95, net -90 points). It is not profitable evidence and the sample is too small to select a production rule.
4. The full EMA stack reduced the sample and did not improve results.
5. These results do not prove Bollinger or EMA100 is inherently ineffective. They test only one precise same-candle combination, fixed 300/300 exits, and one short data window.
6. A next research pass should compare a bounded sequence window (e.g. EMA100 touch followed by Bollinger re-entry within 1–5 M1 bars), and separately test BB middle-band recovery, ATR exits, and a chronological out-of-sample window. Avoid selecting parameters on the same data used to report final performance.

## 9. Conclusion

The CSV source data is present and internally linked. The earlier M1-missing warning is withdrawn. The current data supports a valid first OHLC-level Scenario 2 test, but the exact same-candle setup has not shown a positive edge after the existing 30-point estimated cost.

No changes were made to the EA, trading logic, or any CSV file. This report is an additional research artifact only.
