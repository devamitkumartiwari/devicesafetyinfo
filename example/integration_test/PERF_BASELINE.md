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

## 2.0.0

**Not measured yet.** The harness is updated for 2.0 (same device, same command):

- *Full assessment* runs the same 6 checks as 1.x's `RiskSummary` via
  `DeviceSafety.assess(checks: ..., refresh: true)`: one batched round trip, cache bypassed,
  so the native work runs every time (comparable to 1.x).
- *Cached* is the same call served from the 30 s result cache.
- *All checks* is `DeviceSafety.assess(refresh: true)` over all 15 detection checks.
- *Single* is `DeviceSafety.vpn.check(refresh: true)`.

The on-device functional suite (`integration_test/plugin_test.dart`, 23 tests) passed on the same
Galaxy S21 FE on 2026-11-19; the wireless adb connection dropped before the profile-mode
benchmark could run.
