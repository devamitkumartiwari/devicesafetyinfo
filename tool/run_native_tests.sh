#!/usr/bin/env bash
# Builds test/native/dsi_test.c with the Android NDK and runs it on the connected device or
# emulator (adb). Usage: tool/run_native_tests.sh [arm64-v8a|x86_64] [adb serial]
#
# Needs ANDROID_NDK_HOME (or an NDK under $ANDROID_HOME/ndk or %LOCALAPPDATA%/Android/Sdk/ndk).
set -euo pipefail
# Git Bash on Windows would rewrite /data/local/tmp into a Windows path.
export MSYS_NO_PATHCONV=1

abi="${1:-arm64-v8a}"
serial="${2:-}"
case "$abi" in
  arm64-v8a) target=aarch64-linux-android24 ;;
  x86_64) target=x86_64-linux-android24 ;;
  *) echo "unsupported abi: $abi" >&2; exit 2 ;;
esac

sdk="${ANDROID_HOME:-${LOCALAPPDATA:-$HOME}/Android/Sdk}"
ndk="${ANDROID_NDK_HOME:-$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1)}"
[ -d "$ndk" ] || { echo "Android NDK not found; set ANDROID_NDK_HOME" >&2; exit 2; }
clang=$(ls "$ndk"/toolchains/llvm/prebuilt/*/bin/clang* 2>/dev/null | grep -E 'clang(\.exe)?$' | head -1)
adb="${ADB:-$(command -v adb || echo "$sdk/platform-tools/adb")}"
adb_args=()
[ -n "$serial" ] && adb_args=(-s "$serial")

# `pwd -W` gives a Windows path under Git Bash, which the native Windows clang/adb need.
root="$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))"
mkdir -p "$root/.dart_tool/native_test"
out="$root/.dart_tool/native_test/dsi_test_$abi"
"$clang" --target="$target" -O2 -Wall -Wextra -Werror -fPIE -pie \
  -o "$out" "$root/test/native/dsi_test.c"
"$adb" "${adb_args[@]}" push "$out" /data/local/tmp/dsi_test >/dev/null
"$adb" "${adb_args[@]}" shell chmod 755 /data/local/tmp/dsi_test
"$adb" "${adb_args[@]}" shell /data/local/tmp/dsi_test
