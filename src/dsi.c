// Native anti-tamper checks for device_safety_info. See dsi.h.
//
// These run as plain syscalls from C, which is harder to intercept with Java/Swift-level hooks
// (Frida's Java/ObjC bridges, Xposed) than equivalent platform code.
#include "dsi.h"

#include <string.h>

#if defined(__ANDROID__)

#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

static int frida_in_maps(void) {
  static const char* const patterns[] = {
      "frida", "gum-js-loop", "gmain", "linjector",
      "frida-agent", "re.frida", "frida-gadget", "frida-server",
  };
  FILE* f = fopen("/proc/self/maps", "re");
  if (!f) return 0;
  char line[512];
  int found = 0;
  while (!found && fgets(line, sizeof(line), f)) {
    for (size_t i = 0; i < sizeof(patterns) / sizeof(patterns[0]); i++) {
      if (strstr(line, patterns[i])) {
        found = 1;
        break;
      }
    }
  }
  fclose(f);
  return found;
}

// Non-blocking connect to Frida's default ports. Frida can rename its binaries to evade the
// maps scan, but a listening server is still visible here.
static int frida_port_open(void) {
  static const int ports[] = {27042, 27043};
  for (size_t p = 0; p < sizeof(ports) / sizeof(ports[0]); p++) {
    int sock = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (sock < 0) continue;
    int flags = fcntl(sock, F_GETFL, 0);
    fcntl(sock, F_SETFL, (flags < 0 ? 0 : flags) | O_NONBLOCK);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)ports[p]);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    int open = 0;
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == 0) {
      open = 1;
    } else if (errno == EINPROGRESS) {
      // poll() has no FD_SETSIZE limit, unlike select().
      struct pollfd pfd = {.fd = sock, .events = POLLOUT, .revents = 0};
      if (poll(&pfd, 1, 50) > 0) {
        int err = 0;
        socklen_t len = sizeof(err);
        if (getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len) == 0 && err == 0) {
          open = 1;
        }
      }
    }
    close(sock);
    if (open) return 1;
  }
  return 0;
}

static int tracer_attached(void) {
  FILE* f = fopen("/proc/self/status", "re");
  if (!f) return 0;
  char line[128];
  int traced = 0;
  while (fgets(line, sizeof(line), f)) {
    if (strncmp(line, "TracerPid:", 10) == 0) {
      int pid = 0;
      sscanf(line + 10, "%d", &pid);
      traced = pid != 0;
      break;
    }
  }
  fclose(f);
  return traced;
}

// Returns DSI_ROOT_FILES_HIGH, DSI_ROOT_FILES_LOW or 0.
static uint32_t root_files(void) {
  static const char* const high_paths[] = {
      "/system/bin/magisk", "/sbin/magisk",           "/data/adb/magisk",
      "/sbin/.magisk",      "/system/app/Superuser.apk",
  };
  static const char* const su_paths[] = {
      "/system/xbin/su",     "/system/bin/su",     "/sbin/su",
      "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su",
  };
  struct stat st;
  for (size_t i = 0; i < sizeof(high_paths) / sizeof(high_paths[0]); i++) {
    if (stat(high_paths[i], &st) == 0) return DSI_ROOT_FILES_HIGH;
  }
  uint32_t level = 0;
  for (size_t i = 0; i < sizeof(su_paths) / sizeof(su_paths[0]); i++) {
    if (stat(su_paths[i], &st) == 0) {
      if (access(su_paths[i], X_OK) == 0) return DSI_ROOT_FILES_HIGH;
      level = DSI_ROOT_FILES_LOW;
    }
  }
  return level;
}

#elif defined(__APPLE__)

#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

static int tracer_attached(void) {
  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
  struct kinfo_proc info;
  size_t size = sizeof(info);
  memset(&info, 0, sizeof(info));
  if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return 0;
  return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static int injected_image_loaded(void) {
  static const char* const patterns[] = {
      "FridaGadget", "frida",        "MobileSubstrate", "SubstrateLoader",
      "libhooker",   "TweakInject",  "cynject",         "libcycript",
      "SSLKillSwitch", "SubstrateInserter", "ellekit",
  };
  uint32_t count = _dyld_image_count();
  for (uint32_t i = 0; i < count; i++) {
    const char* name = _dyld_get_image_name(i);
    if (!name) continue;
    for (size_t p = 0; p < sizeof(patterns) / sizeof(patterns[0]); p++) {
      if (strstr(name, patterns[p])) return 1;
    }
  }
  return 0;
}

#endif

DSI_EXPORT uint32_t dsi_collect_signals(uint32_t mask) {
  uint32_t out = 0;
#if defined(__ANDROID__)
  if ((mask & DSI_FRIDA_MAPS) && frida_in_maps()) out |= DSI_FRIDA_MAPS;
  if ((mask & DSI_FRIDA_PORT) && frida_port_open()) out |= DSI_FRIDA_PORT;
  if ((mask & DSI_DEBUGGER) && tracer_attached()) out |= DSI_DEBUGGER;
  if (mask & (DSI_ROOT_FILES_HIGH | DSI_ROOT_FILES_LOW)) {
    out |= root_files() & mask;
  }
#elif defined(__APPLE__)
  if ((mask & DSI_DEBUGGER) && tracer_attached()) out |= DSI_DEBUGGER;
  if ((mask & DSI_DYLD_INJECTION) && injected_image_loaded()) out |= DSI_DYLD_INJECTION;
#else
  (void)mask;
#endif
  return out;
}

DSI_EXPORT uint32_t dsi_abi_version(void) { return DSI_ABI_VERSION; }
