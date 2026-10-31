# Scenario 3 — EMA + MACD Analysis
Date: 2026-10-31
Repository: behrooz64/MT5 | Branch: TRX | Symbol: XAUUSDb
Source EA: EMAMonitor_v3_1.mq5 (blob 9c10fc76bf907ef18e5b84c2a0fdc0e66a4010ab)

## Rule tested
BUY: MACD main crosses above signal while EMA50 > EMA100 > EMA200.
SELL: MACD main crosses below signal while EMA50 < EMA100 < EMA200.
The EMA stack definition is taken directly from the collector. EMA15 is not part of its native bull/bear stack.

## Data
M1 Bars: 6,323 (2026-10-23 23:54 to 2026-10-30 13:31).
M5 Bars: 1,267 (2026-10-23 23:50 to 2026-10-30 13:25).
H1 exports have headers only. Recorded tick size is 0.01. Large data gaps exist; exit simulations interrupted by a gap are excluded.

## Method
Completed candle signal; entry at signal close; exits start on next candle. Baseline TP/SL 300/300 points, estimated cost 30 points deducted once, maximum 120 bars. If TP and SL are both touched in one candle, SL is counted first. 300 points equals 3.00 in price at the recorded 0.01 point size. M1 higher-timeframe filter tests use only the latest fully closed M5 candle. Signals may overlap; this is not an account-level portfolio simulation.

## Primary results: same-timeframe EMA stack + MACD, fixed TP/SL
| TF / direction | Completed | Wins | Losses | Win rate | Net points | PF |
|---|---:|---:|---:|---:|---:|---:|
| M1 BUY | 80 | 38 | 42 | 47.5% | -3,600 | 0.740 |
| M1 SELL | 120 | 62 | 58 | 51.7% | -2,400 | 0.875 |
| M1 total | 200 | 100 | 100 | 50.0% | -6,000 | 0.818 |
| M5 BUY | 11 | 9 | 2 | 81.8% | +1,770 | 3.682 |
| M5 SELL | 28 | 16 | 12 | 57.1% | +360 | 1.091 |
| M5 total | 39 | 25 | 14 | 64.1% | +2,130 | 1.461 |

203 M1 signals were detected; 3 were excluded because a gap interrupted the exit window. M5 BUY has only 11 observations and is not statistically reliable.

## Baseline: native MACD cross alone, FIXED_TP_SL
| TF / direction | Signals | Win rate | Net points | PF |
|---|---:|---:|---:|---:|
| M1 BUY | 255 | 54.1% | -1,350 | 0.965 |
| M1 SELL | 256 | 50.4% | -6,873 | 0.835 |
| M5 BUY | 57 | 50.9% | -1,410 | 0.847 |
| M5 SELL | 57 | 47.4% | -2,610 | 0.736 |

EMA stack materially improved the M5 fixed-exit aggregate, reducing native MACD signals from 114 to 39. It did not rescue M1.

## M1 with fully closed M5 EMA-stack filter
199 completed: BUY 84, 53.6% wins, -720 points, PF 0.944; SELL 115, 47.8% wins, -4,950 points, PF 0.750. This does not establish a profitable M1 setup.

## M5 exit sensitivity
| Exit | Completed | Wins | Losses | Win rate | Net points | PF |
|---|---:|---:|---:|---:|---:|---:|
| Fixed 300/300 | 39 | 25 | 14 | 64.1% | +2,130 | 1.461 |
| Fixed RR 2:1 (600/300) | 36 | 19 | 17 | 52.8% | +5,220 | 1.930 |
| ATR TP 1.5 / SL 1.0 | 38 | 20 | 18 | 52.6% | +2,677 | 1.350 |

RR 2:1 direction split: BUY 9 trades, +1,530 points, PF 2.159; SELL 27 trades, +3,690 points, PF 1.860. ATR split: BUY 11 trades, +599.5 points, PF 1.374; SELL 27 trades, +2,077.5 points, PF 1.344. Gap-interrupted signals were excluded.

## Chronological stability
Signals split into two roughly equal chronological groups:
- Fixed 300/300: earlier 19 trades, -270 points, PF 0.909; later 20 trades, +2,400 points, PF 2.455.
- RR 2:1: earlier 18 trades, +360 points, PF 1.099; later 18 trades, +4,860 points, PF 3.455.
- ATR 1.5/1.0: earlier 19 trades, -1,582.5 points, PF 0.645; later 19 trades, +4,259.5 points, PF 2.336.

This large performance split shows market-phase sensitivity. The later group contains only 18–20 observations and is not an independent validation sample.

## Conclusion
1. M1 EMA+MACD is negative in this test: PF 0.818, -6,000 points.
2. M5 EMA+MACD is the only candidate worth further forward testing: fixed exits PF 1.461 over 39 observations.
3. M5 BUY's 11-trade result is too small to trust; M5 SELL's fixed-exit PF is only 1.091.
4. RR 2:1 looks best in the short M5 sample, but the chronological split is highly uneven.
5. Do not deploy or change the EA based on this report. Continue M5 collection, separate BUY/SELL, and validate on a fresh untouched period.

## Limitations and change control
Short sample, collection gaps, overlapping independent signals, simplified flat cost, and no portfolio margin/exposure, commission, swap, live slippage or latency model. No EA, trading logic, or raw CSV was changed; no other branch was modified.
