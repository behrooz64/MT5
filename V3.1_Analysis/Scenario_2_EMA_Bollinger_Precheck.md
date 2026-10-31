# Scenario 2 | EMA + Bollinger Bands
## V3.1 research pre-check

- Repository: `behrooz64/MT5`
- Branch: `TRX`
- Reference EA: `EMAMonitor_v3_1.mq5`
- Reference EA blob: `9c10fc76bf907ef18e5b84c2a0fdc0e66a4010ab`
- Scope: statistical research only; no EA logic or source CSV was changed.
- Symbol: `XAUUSDb`

## 1. Scenario definition

1. Use the last fully closed M5 candle to determine trend direction from EMA200.
2. On M1, wait for price to test EMA100 in the direction of the M5 trend.
3. Evaluate the M1 price location relative to Bollinger middle and outer bands.
4. Require a completed-candle reversal confirmation; a line/band touch alone is not an entry.
5. Keep BUY and SELL results separate.

V3.1 source defaults relevant to the test: Bollinger period 20, deviation 2.0, applied price Close. The scenario's trend/pullback settings are EMA200 on M5 and EMA100 on M1. Existing V3.1 costs and exit assumptions must be carried through unchanged when the actual simulation is run.

## 2. Source-data audit

The TRX branch currently exposes these M1 files as zero-byte files:
- `EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Bars.csv` (expected populated data, current fetch: 0 bytes)
- `EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Events.csv` (0 bytes)
- `EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Outcomes.csv` (0 bytes)
- `EMAMonitor_v3_1_XAUUSDb_PERIOD_M1_Scenarios.csv` (0 bytes)

Therefore the required M1 EMA100 touch, M1 Bollinger position, and closed-candle reversal cannot currently be reconstructed. No M1 entry count, win rate, profit factor, net points, or drawdown is reported. The earlier M1 working snapshot mentioned in the Stage 1 report is not present in the current branch files and is not treated as reproducible evidence.

Available M5 context:
- File: `EMAMonitor_v3_1_XAUUSDb_PERIOD_M5_Bars.csv`
- Blob: `7d9ac6fe78842726a30b0357bcfc2059e36b41d0`
- Rows: 1,267
- Time window: 2026-10-23 23:50:00 to 2026-10-30 13:25:00
- Close above / below EMA200: 550 / 716 bars (1 bar equal to EMA200)
- EMA bullish / bearish stack: 444 / 558 bars
- High touched upper BB: 146 bars
- Low touched lower BB: 175 bars
- Upper-band touch followed by close back below upper band: 73 bars
- Lower-band touch followed by close back above lower band: 98 bars
- Mean recorded spread: 12.32 points
- Median BB width: 1,416.2 points

These are M5 context counts only. They are not Scenario 2 trades, are not M1 confirmation counts, and do not establish profitability.

## 3. Execution status

**Status: BLOCKED for the full Scenario 2 simulation by missing M1 source data.**

The available M5 series can describe the broad trend and M5 Bollinger context, but it cannot stand in for the missing M1 candles without changing the approved scenario. In particular, deriving M1 touches or confirmations from M5 OHLC would create false precision and could miss intrabar order.

## 4. Exact data needed to complete the test

Re-export the following from the V3.1 collector for XAUUSDb:
- M1 Bars CSV (required: OHLC, EMA100, EMA200, BB upper/middle/lower, spread, timestamps)
- M1 Events CSV (if emitted by the collector)
- M1 Outcomes CSV (if emitted by the collector)
- M1 Scenarios CSV (if emitted by the collector)

Then re-run the scenario with a strict time join: at each M1 signal, use only the most recent fully closed M5 candle. Never use an M5 candle that closes after the M1 signal timestamp. Preserve the V3.1 source's cost and exit mechanics, and report BUY/SELL separately with sample count, win rate, average net points, profit factor, max drawdown, and out-of-sample stability.

## 5. Change-control

No changes were made to `EMAMonitor_v3_1.mq5`, any trading logic, or any other branch. This document is a research pre-check only.
