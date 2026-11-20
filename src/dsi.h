// Native anti-tamper checks for device_safety_info.
//
// One entry point: pass a mask of the checks to run, get back a mask of the ones that fired.
// Dart bindings are generated from this header by FFIgen (ffigen.yaml); the library is built
// for Android and iOS by hook/build.dart.
#ifndef DSI_H_
#define DSI_H_

#include <stdint.h>

#if defined(_WIN32)
#define DSI_EXPORT __declspec(dllexport)
#else
#define DSI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Bumped whenever a bit's meaning or the function signatures change. Dart refuses to use a
// library whose version it doesn't know.
#define DSI_ABI_VERSION 1u

// Frida library names in /proc/self/maps (Android).
#define DSI_FRIDA_MAPS (1u << 0)
// Something accepts connections on 127.0.0.1:27042/27043, Frida's default ports (Android).
#define DSI_FRIDA_PORT (1u << 1)
// A debugger is attached: TracerPid != 0 (Android) or P_TRACED (iOS).
#define DSI_DEBUGGER (1u << 2)
// An executable su, or a Magisk/Superuser artifact, exists (Android).
#define DSI_ROOT_FILES_HIGH (1u << 3)
// An su binary exists but this app can't execute it (Android; some stock ROMs ship one).
#define DSI_ROOT_FILES_LOW (1u << 4)
// A loaded image is a known injection library (FridaGadget, Substrate, ...) (iOS).
#define DSI_DYLD_INJECTION (1u << 5)

#define DSI_ALL_CHECKS                                                    \
  (DSI_FRIDA_MAPS | DSI_FRIDA_PORT | DSI_DEBUGGER | DSI_ROOT_FILES_HIGH | \
   DSI_ROOT_FILES_LOW | DSI_DYLD_INJECTION)

// Runs the checks in `mask` and returns the bits of those that fired. Checks that don't apply
// to the current platform never fire. Blocking for up to ~100 ms (the port probe); call it off
// the UI thread.
DSI_EXPORT uint32_t dsi_collect_signals(uint32_t mask);

// Returns DSI_ABI_VERSION.
DSI_EXPORT uint32_t dsi_abi_version(void);

#ifdef __cplusplus
}
#endif

#endif  // DSI_H_
