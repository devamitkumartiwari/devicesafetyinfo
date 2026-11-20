# Performance baseline

Measured with `perf_test.dart` (see its header for the command), profile mode.

## 1.7.0 (before the 2.0 refactor), 2026-11-19

Device: Samsung Galaxy S21 FE (SM-G990B2), Android 16 (API 36), wireless adb.
Flutter 3.50.0. Full assessment = `RiskSummary.evaluate()` (6 parallel channel calls).

| Metric | Value |
|---|---|
| Full assessment, cold (first call after launch) | 60.4 ms / 115.6 ms (two runs) |
| Full assessment, warm, 20 runs: median / p95 | 12.2 ms / 16.0 ms |
| Single check (`isVPNCheck`), 20 runs: median / p95 | 1.5 ms / 1.9 ms |
| Frame build while assessing: median / p95 | 0.35 ms / 0.43 ms |
| Frame raster while assessing: median / p95 / max | 1.57 ms / 1.89 ms / 8.64 ms |

iOS: not measured (no Mac available).

## 2.0.0, 2026-11-20

Same device, same command, two profile-mode runs (ranges show both).

| Metric | 1.x | 2.0 |
|---|---|---|
| Full assessment (6 `RiskSummary` checks), cold | 60.4 / 115.6 ms | 107.2 / 109.5 ms |
| Same, 20 repeats, uncached: median / p95 | 12.2 / 16.0 ms | 50.6–50.8 / 66.1–69.4 ms |
| Same, served from the result cache: median | n/a | 0.011–0.014 ms |
| All 15 detection checks, uncached: median / p95 | n/a | 44.7–45.0 / 49.0–51.1 ms |
| Single check (VPN), uncached: median / p95 | 1.5 / 1.9 ms | 4.7–5.1 / 5.4 ms |
| Frame build p95 while assessing | 0.43 ms | 0.38–0.41 ms |
| Frame raster p95 / max while assessing | 1.89 / 8.6 ms | 3.2–3.9 / 8.5–18.0 ms |

How to read this:

- **Repeated checks are not like-for-like.** 1.x cached root and hook results natively for 30 s,
  so its "warm" runs skipped that work. 2.0's uncached row (`refresh: true`) redoes all native
  work every time, including the C checks on a background isolate. A normal 2.0 repeat call is
  served by the Dart cache (about 0.01 ms).
- **Cold assessment is about the same** (one batched call vs six channel calls).
- **A single uncached check is slower** (about 5 ms vs 1.5 ms). In 1.x the VPN check ran
  synchronously on the Android main thread; in 2.0 it hops to the shared background pool and back.
- 2.0 does more per run: proxy detection, the RWX maps scan, Xposed class checks, and the C checks.
- The UI thread stays free: frame build times are unchanged.

So the plan's "2 to 3 times faster" estimate did not hold for uncached work. The gains are the
result cache (repeat calls are effectively free), request de-duplication, and no blocking work on
the UI thread.
