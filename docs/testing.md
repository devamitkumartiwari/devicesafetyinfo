# Device test matrix

Unit tests cover the detection logic with fixtures. They can't show that a check fires on a real
rooted or hooked device, or that it stays quiet on a clean one. Run this matrix before a release
that changes detection, and record the results (date, device, OS, package version) in the PR.

## Automated, on any device or emulator

```sh
tool/run_native_tests.sh arm64-v8a            # phone; x86_64 for the emulator
cd example && flutter test integration_test/plugin_test.dart -d <device>
```

`run_native_tests.sh` also recreates Frida's footprints itself: a `gum-js-loop` thread, a
`linjector` file descriptor, a listener on port 27042, and a patched byte of libc. Each
detector must catch its footprint and go quiet once it's removed. `plugin_test.dart` prints every
root, emulator and hooking signal, fails on any high-risk root or hooking signal, and checks the
tampering check with the real and a wrong certificate.

## Manual matrix

Use the example app's Root, Hooking, Emulator and Tampering pages, or `DeviceSafety.assess()`.

| # | Setup | Expected |
|---|---|---|
| 1 | Stock phone, locked bootloader | `root`, `hooking`, `emulator`, `tampering` not detected; no high signal at all |
| 2 | Stock phone, unlocked bootloader, not rooted | low only: `root.verifiedboot_unlocked`, `root.bootloader_unlocked` |
| 3 | Magisk, Zygisk on, app **not** on the DenyList | high: `root.manager_app`, `root.mount_marker` / `root.native_mounts`, often `root.binary_executable` |
| 4 | Magisk + DenyList + Shamiko, package renamed | expect little or nothing on-device; Play Integrity `MEETS_STRONG_INTEGRITY` absent. Documents the limit. |
| 5 | KernelSU / APatch | high: `root.manager_app` (if the manager is installed), `root.mount_marker` (`KSU` / `APatch` source) |
| 6 | LSPosed module hooking `File.exists` to return false | `integrity.layer_mismatch:root_files` plus the C-side `root.native_files` |
| 7 | `frida-server` (default port) + `frida -U -f <app>` | high: `hooking.frida_maps`, `hooking.frida_threads`, `hooking.frida_port`, `hooking.text_patched` once a libc function is hooked |
| 8 | `frida-server -l 0.0.0.0:31337`, renamed binary, `objection ... android root disable` | high: `hooking.frida_threads` and/or `hooking.text_patched`; `root.*` from C still reported |
| 9 | Frida gadget embedded in a re-signed APK | high: `hooking.frida_maps` or `hooking.frida_threads`; `tampering.signature_mismatch` |
| 10 | Android Studio emulator (Google Play image) | `emulator` detected (`emulator.hardware:ranchu`, `emulator.qemu`) |
| 11 | Genymotion, BlueStacks, Nox, MEmu, LDPlayer | `emulator` detected (`emulator.file`, `emulator.hardware`, `emulator.build_name`) |
| 12 | APK decompiled with apktool, rebuilt, re-signed | `tampering.signature_mismatch` |
| 13 | iOS, App Store / TestFlight build | `tampering` clean; `root` not detected |
| 14 | iOS, rootless jailbreak (Dopamine, palera1n) | high: `root.native_jailbreak_files` and/or `root.jailbreak_*` |
| 15 | iOS, IPA re-signed with another team (AltStore, Sideloadly) | `tampering.team_id_mismatch` (with `expectedIosTeamId` set) |

Rows 4 and 8 deliberately probe the limits: record what fired, not just pass/fail.

## Last recorded runs

| Date | Device | Result |
|---|---|---|
| 2026-11-20 | Samsung Galaxy (arm64, stock, One UI) | native tests pass incl. live Frida footprints; clean `0x0`; libc compared 593 KB, injected patch detected. `plugin_test.dart`: root, emulator, hooking clean (no high or low signals), tampering pass; 1 failure in the unrelated `isCallActive()` assertion (call detection returned true on the phone at the time) |
| 2026-11-20 | Android Studio emulator, Pixel 8a image (x86_64) | native tests pass incl. live Frida footprints; `plugin_test.dart` 26/26; emulator detected via `ranchu`, qemu props, build names |
