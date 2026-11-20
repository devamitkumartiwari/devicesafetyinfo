// Native anti-tamper checks for device_safety_info. See dsi.h.
//
// On arm64 and x86_64 Android the security-relevant file reads issue system calls directly
// (svc / syscall instructions), so hooking libc's open/stat/access (the usual Frida root-bypass
// scripts) doesn't blind them. Other ABIs fall back to libc. Detection strings come from
// dsi_signatures.g.h, generated from tool/signatures.json, and are stored encoded.
#include "dsi.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "dsi_signatures.g.h"

// ---------------------------------------------------------------------------------------------
// Encoded string lists (all platforms)
// ---------------------------------------------------------------------------------------------

typedef struct {
  const dsi_sig_t* sig;
  unsigned int pos;
} dsi_sig_iter;

// Decodes the next entry of a list into `out` (truncated to `cap` - 1 bytes). Returns 0 when
// the list is exhausted. Must match encode() in tool/gen_signatures.dart.
static int dsi_sig_next(dsi_sig_iter* it, char* out, size_t cap) {
  const dsi_sig_t* s = it->sig;
  if (it->pos > s->len) return 0;
  size_t n = 0;
  for (;;) {
    if (it->pos == s->len) {
      it->pos = s->len + 1;
      break;
    }
    unsigned char c = (unsigned char)(s->data[it->pos] ^
                                      (unsigned char)((s->seed + it->pos * 167u) & 0xffu));
    it->pos++;
    if (c == 0) break;
    if (n + 1 < cap) out[n++] = (char)c;
  }
  out[n] = 0;
  return 1;
}

// Whether `hay` contains any entry of `sig`.
static int dsi_sig_any_in(const dsi_sig_t* sig, const char* hay) {
  dsi_sig_iter it = {sig, 0};
  char entry[256];
  while (dsi_sig_next(&it, entry, sizeof(entry))) {
    if (entry[0] && strstr(hay, entry)) return 1;
  }
  return 0;
}

#if defined(__ANDROID__)

#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <unistd.h>

// ---------------------------------------------------------------------------------------------
// Direct system calls. Each returns the kernel result: >= 0 on success, -errno on failure.
// ---------------------------------------------------------------------------------------------

#if defined(__aarch64__)
static long dsi_sys4(long n, long a, long b, long c, long d) {
  register long x8 __asm__("x8") = n;
  register long x0 __asm__("x0") = a;
  register long x1 __asm__("x1") = b;
  register long x2 __asm__("x2") = c;
  register long x3 __asm__("x3") = d;
  __asm__ volatile("svc #0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3) : "memory", "cc");
  return x0;
}
#define DSI_RAW_SYSCALLS 1
#elif defined(__x86_64__)
static long dsi_sys4(long n, long a, long b, long c, long d) {
  long ret;
  register long r10 __asm__("r10") = d;
  __asm__ volatile("syscall"
                   : "=a"(ret)
                   : "a"(n), "D"(a), "S"(b), "d"(c), "r"(r10)
                   : "rcx", "r11", "memory", "cc");
  return ret;
}
#define DSI_RAW_SYSCALLS 1
#else
// 32-bit ABIs: libc's syscall() (r7/ebx are reserved registers there, so inline asm is fragile).
static long dsi_sys4(long n, long a, long b, long c, long d) {
  long r = syscall(n, a, b, c, d);
  return r < 0 ? -errno : r;
}
#endif

static int dsi_open(const char* path, int flags) {
  return (int)dsi_sys4(__NR_openat, AT_FDCWD, (long)path, flags | O_CLOEXEC, 0);
}

static int dsi_openat(int dirfd, const char* path, int flags) {
  return (int)dsi_sys4(__NR_openat, dirfd, (long)path, flags | O_CLOEXEC, 0);
}

static long dsi_read(int fd, void* buf, size_t n) {
  return dsi_sys4(__NR_read, fd, (long)buf, (long)n, 0);
}

static void dsi_close(int fd) { dsi_sys4(__NR_close, fd, 0, 0, 0); }

static long dsi_pread(int fd, void* buf, size_t n, long long off) {
#if defined(DSI_RAW_SYSCALLS)
  return dsi_sys4(__NR_pread64, fd, (long)buf, (long)n, (long)off);
#else
  long r = pread64(fd, buf, n, off);
  return r < 0 ? -errno : r;
#endif
}

static int dsi_access(const char* path, int mode) {
  return (int)dsi_sys4(__NR_faccessat, AT_FDCWD, (long)path, mode, 0);
}

static long dsi_readlinkat(int dirfd, const char* path, char* buf, size_t n) {
  return dsi_sys4(__NR_readlinkat, dirfd, (long)path, (long)buf, (long)n);
}

static long dsi_getdents(int fd, void* buf, size_t n) {
  return dsi_sys4(__NR_getdents64, fd, (long)buf, (long)n, 0);
}

struct dsi_dirent {
  uint64_t d_ino;
  int64_t d_off;
  unsigned short d_reclen;
  unsigned char d_type;
  char d_name[];
};

// ---------------------------------------------------------------------------------------------
// Line reader over a file descriptor
// ---------------------------------------------------------------------------------------------

// Large enough for a whole maps or mounts line (header plus a PATH_MAX path), so a name is
// never split across two reads.
#define DSI_LINE_MAX (4096 + 256)

typedef struct {
  int fd;
  size_t len;
  size_t pos;
  char buf[4096];
} dsi_reader;

// Reads the next line (without '\n') into `line`; longer lines are truncated. Returns 0 at EOF.
static int dsi_readline(dsi_reader* r, char* line, size_t cap) {
  size_t n = 0;
  int got = 0;
  for (;;) {
    if (r->pos == r->len) {
      long k = dsi_read(r->fd, r->buf, sizeof(r->buf));
      if (k <= 0) break;
      r->len = (size_t)k;
      r->pos = 0;
    }
    char c = r->buf[r->pos++];
    got = 1;
    if (c == '\n') break;
    if (n + 1 < cap) line[n++] = c;
  }
  line[n] = 0;
  return got;
}

// ---------------------------------------------------------------------------------------------
// Pure line classifiers (unit-tested in test/native/dsi_test.c)
// ---------------------------------------------------------------------------------------------

static int dsi_ascii_lower(int c) { return c >= 'A' && c <= 'Z' ? c + 32 : c; }

static int dsi_streq_nocase(const char* a, const char* b) {
  while (*a && *b) {
    if (dsi_ascii_lower((unsigned char)*a) != dsi_ascii_lower((unsigned char)*b)) return 0;
    a++;
    b++;
  }
  return *a == *b;
}

// A /proc/self/maps line that names Frida.
static int dsi_maps_line_frida(const char* line) {
  return dsi_sig_any_in(&DSI_SIG_FRIDA_MAP_MARKERS, line);
}

// Splits the next space-separated field of `*s` into `out`. Returns 0 if there is none.
static int dsi_field(const char** s, char* out, size_t cap) {
  const char* p = *s;
  while (*p == ' ' || *p == '\t') p++;
  if (!*p) return 0;
  size_t n = 0;
  while (*p && *p != ' ' && *p != '\t') {
    if (n + 1 < cap) out[n++] = *p;
    p++;
  }
  out[n] = 0;
  *s = p;
  return 1;
}

static int dsi_in_list(const dsi_sig_t* sig, const char* value, int prefix) {
  dsi_sig_iter it = {sig, 0};
  char entry[256];
  while (dsi_sig_next(&it, entry, sizeof(entry))) {
    size_t n = strlen(entry);
    if (prefix ? strncmp(value, entry, n) == 0 : strcmp(value, entry) == 0) return 1;
  }
  return 0;
}

// A /proc/mounts line showing systemless root. Mirrors MountChecker.kt.
static int dsi_mount_line_suspicious(const char* line) {
  char source[512], point[512], fs[64], opts[2048];
  const char* p = line;
  if (!dsi_field(&p, source, sizeof(source)) || !dsi_field(&p, point, sizeof(point)) ||
      !dsi_field(&p, fs, sizeof(fs)) || !dsi_field(&p, opts, sizeof(opts))) {
    return 0;
  }
  dsi_sig_iter it = {&DSI_SIG_MOUNT_SOURCES, 0};
  char entry[64];
  while (dsi_sig_next(&it, entry, sizeof(entry))) {
    if (dsi_streq_nocase(source, entry)) return 1;
  }
  if (dsi_sig_any_in(&DSI_SIG_MOUNT_OPTION_MARKERS, opts)) return 1;

  int disk_fs = !strcmp(fs, "ext4") || !strcmp(fs, "erofs") || !strcmp(fs, "f2fs") ||
                !strcmp(fs, "squashfs") || !strcmp(fs, "overlay");
  int rw = strncmp(opts, "rw", 2) == 0 && (opts[2] == ',' || opts[2] == 0);
  if (disk_fs && rw && dsi_in_list(&DSI_SIG_PROTECTED_MOUNT_POINTS, point, 0)) return 1;

  int overlay_fs = !strcmp(fs, "tmpfs") || !strcmp(fs, "overlay");
  if (overlay_fs && dsi_in_list(&DSI_SIG_PROTECTED_MOUNT_PREFIXES, point, 1)) return 1;
  return 0;
}

// A thread name that only Frida's agent uses. `gmain` and `gdbus` are GLib's threads: either
// alone could be a legitimate GLib-based library, both together are flagged by the caller.
static int dsi_comm_is_frida(const char* comm, int* saw_gmain, int* saw_gdbus) {
  if (!strcmp(comm, "gmain")) *saw_gmain = 1;
  if (!strcmp(comm, "gdbus")) *saw_gdbus = 1;
  return dsi_sig_any_in(&DSI_SIG_FRIDA_THREAD_NAMES, comm);
}

// Parses a maps line into its address range, permissions, file offset and path.
static int dsi_parse_maps_line(const char* line, uintptr_t* start, uintptr_t* end, char perms[5],
                               unsigned long long* offset, const char** path) {
  char* e = NULL;
  unsigned long long s = strtoull(line, &e, 16);
  if (!e || *e != '-') return 0;
  unsigned long long t = strtoull(e + 1, &e, 16);
  if (!e || *e != ' ') return 0;
  e++;
  for (int i = 0; i < 4; i++) {
    if (!e[i]) return 0;
    perms[i] = e[i];
  }
  perms[4] = 0;
  e += 4;
  unsigned long long off = strtoull(e, &e, 16);
  // dev and inode
  const char* p = e;
  char skip[64];
  if (!dsi_field(&p, skip, sizeof(skip)) || !dsi_field(&p, skip, sizeof(skip))) return 0;
  while (*p == ' ') p++;
  *start = (uintptr_t)s;
  *end = (uintptr_t)t;
  *offset = off;
  *path = p;
  return 1;
}

static int dsi_ends_with(const char* s, const char* suffix) {
  size_t a = strlen(s), b = strlen(suffix);
  return a >= b && strcmp(s + a - b, suffix) == 0;
}

// ---------------------------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------------------------

static int frida_in_maps(void) {
  int fd = dsi_open("/proc/self/maps", O_RDONLY);
  if (fd < 0) return 0;
  dsi_reader r = {fd, 0, 0, {0}};
  char line[DSI_LINE_MAX];
  int found = 0;
  while (!found && dsi_readline(&r, line, sizeof(line))) found = dsi_maps_line_frida(line);
  dsi_close(fd);
  return found;
}

static int frida_threads(void) {
  int dir = dsi_open("/proc/self/task", O_RDONLY | O_DIRECTORY);
  if (dir < 0) return 0;
  char buf[4096];
  int found = 0, saw_gmain = 0, saw_gdbus = 0;
  long n;
  while (!found && (n = dsi_getdents(dir, buf, sizeof(buf))) > 0) {
    for (long off = 0; off < n && !found;) {
      struct dsi_dirent* d = (struct dsi_dirent*)(buf + off);
      off += d->d_reclen;
      if (d->d_name[0] < '0' || d->d_name[0] > '9') continue;
      char path[64];
      size_t len = strlen(d->d_name);
      if (len > 32) continue;
      memcpy(path, d->d_name, len);
      memcpy(path + len, "/comm", 6);
      int fd = dsi_openat(dir, path, O_RDONLY);
      if (fd < 0) continue;
      char comm[64];
      long k = dsi_read(fd, comm, sizeof(comm) - 1);
      dsi_close(fd);
      if (k <= 0) continue;
      comm[k] = 0;
      if (comm[k - 1] == '\n') comm[k - 1] = 0;
      found = dsi_comm_is_frida(comm, &saw_gmain, &saw_gdbus);
    }
  }
  dsi_close(dir);
  return found || (saw_gmain && saw_gdbus);
}

static int frida_fds(void) {
  int dir = dsi_open("/proc/self/fd", O_RDONLY | O_DIRECTORY);
  if (dir < 0) return 0;
  char buf[4096];
  int found = 0;
  long n;
  while (!found && (n = dsi_getdents(dir, buf, sizeof(buf))) > 0) {
    for (long off = 0; off < n && !found;) {
      struct dsi_dirent* d = (struct dsi_dirent*)(buf + off);
      off += d->d_reclen;
      if (d->d_name[0] < '0' || d->d_name[0] > '9') continue;
      char target[512];
      long k = dsi_readlinkat(dir, d->d_name, target, sizeof(target) - 1);
      if (k <= 0) continue;
      target[k] = 0;
      found = dsi_sig_any_in(&DSI_SIG_FRIDA_FD_MARKERS, target);
    }
  }
  dsi_close(dir);
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

// Compares libc's executable mappings with the bytes on disk. Inline hooks (Frida's
// Interceptor, used by root-bypass scripts on open/access/stat/fopen) rewrite function
// prologues in memory. Android forbids text relocations, so an unpatched mapping matches the
// file exactly. Mappings without read permission (execute-only memory) are skipped; a page a
// hook left writable is still compared.
// `compared` (optional) receives the number of bytes compared, for tests.
static int libc_text_check(size_t* compared) {
  if (compared) *compared = 0;
  int maps = dsi_open("/proc/self/maps", O_RDONLY);
  if (maps < 0) return 0;
  dsi_reader r = {maps, 0, 0, {0}};
  char line[DSI_LINE_MAX];
  int patched = 0;
  while (!patched && dsi_readline(&r, line, sizeof(line))) {
    uintptr_t start, end;
    char perms[5];
    unsigned long long offset;
    const char* path;
    if (!dsi_parse_maps_line(line, &start, &end, perms, &offset, &path)) continue;
    // Readable and executable: r-xp normally, rwxp while (or after) a hook rewrites it.
    if (perms[0] != 'r' || perms[2] != 'x' || !dsi_ends_with(path, "/libc.so")) continue;
    int fd = dsi_open(path, O_RDONLY);
    if (fd < 0) continue;
    char chunk[8192];
    for (uintptr_t at = start; at < end && !patched;) {
      size_t want = end - at < sizeof(chunk) ? (size_t)(end - at) : sizeof(chunk);
      long got = dsi_pread(fd, chunk, want, (long long)(offset + (at - start)));
      if (got <= 0) break;  // past EOF: padding the linker added, nothing to compare
      if (memcmp((const void*)at, chunk, (size_t)got) != 0) patched = 1;
      at += (uintptr_t)got;
      if (compared) *compared += (size_t)got;
    }
    dsi_close(fd);
  }
  dsi_close(maps);
  return patched;
}

static int libc_text_patched(void) { return libc_text_check(NULL); }

static int tracer_attached(void) {
  int fd = dsi_open("/proc/self/status", O_RDONLY);
  if (fd < 0) return 0;
  dsi_reader r = {fd, 0, 0, {0}};
  char line[256];
  int traced = 0;
  while (dsi_readline(&r, line, sizeof(line))) {
    if (strncmp(line, "TracerPid:", 10) == 0) {
      traced = strtol(line + 10, NULL, 10) != 0;
      break;
    }
  }
  dsi_close(fd);
  return traced;
}

// Returns DSI_ROOT_FILES_HIGH, DSI_ROOT_FILES_LOW or 0. Same lists as RootFilesChecker.kt.
static uint32_t root_files(void) {
  char path[256];
  dsi_sig_iter managers = {&DSI_SIG_ROOT_MANAGER_PATHS, 0};
  while (dsi_sig_next(&managers, path, sizeof(path))) {
    if (dsi_access(path, F_OK) == 0) return DSI_ROOT_FILES_HIGH;
  }
  uint32_t level = 0;
  dsi_sig_iter su = {&DSI_SIG_SU_PATHS, 0};
  while (dsi_sig_next(&su, path, sizeof(path))) {
    if (dsi_access(path, F_OK) == 0) {
      if (dsi_access(path, X_OK) == 0) return DSI_ROOT_FILES_HIGH;
      level = DSI_ROOT_FILES_LOW;
    }
  }
  return level;
}

static int root_mounts(void) {
  int fd = dsi_open("/proc/self/mounts", O_RDONLY);
  if (fd < 0) return 0;
  dsi_reader r = {fd, 0, 0, {0}};
  char line[DSI_LINE_MAX];
  int found = 0;
  while (!found && dsi_readline(&r, line, sizeof(line))) found = dsi_mount_line_suspicious(line);
  dsi_close(fd);
  return found;
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
  if (getenv("DYLD_INSERT_LIBRARIES") != NULL) return 1;
  uint32_t count = _dyld_image_count();
  for (uint32_t i = 0; i < count; i++) {
    const char* name = _dyld_get_image_name(i);
    if (name && dsi_sig_any_in(&DSI_SIG_IOS_INJECTED_IMAGES, name)) return 1;
  }
  return 0;
}

// A second opinion to IOSSecuritySuite, from C and off the main thread: jailbreak files that
// a stock, sandboxed iOS install never has (rootful and rootless /var/jb layouts).
static int jailbreak_files(void) {
  dsi_sig_iter it = {&DSI_SIG_IOS_JAILBREAK_PATHS, 0};
  char path[256];
  while (dsi_sig_next(&it, path, sizeof(path))) {
    if (access(path, F_OK) == 0) return 1;
  }
  return 0;
}

#endif

DSI_EXPORT uint32_t dsi_collect_signals(uint32_t mask) {
  uint32_t out = 0;
#if defined(__ANDROID__)
  if ((mask & DSI_FRIDA_MAPS) && frida_in_maps()) out |= DSI_FRIDA_MAPS;
  if ((mask & DSI_FRIDA_THREADS) && frida_threads()) out |= DSI_FRIDA_THREADS;
  if ((mask & DSI_FRIDA_FDS) && frida_fds()) out |= DSI_FRIDA_FDS;
  if ((mask & DSI_FRIDA_PORT) && frida_port_open()) out |= DSI_FRIDA_PORT;
  if ((mask & DSI_TEXT_PATCHED) && libc_text_patched()) out |= DSI_TEXT_PATCHED;
  if ((mask & DSI_DEBUGGER) && tracer_attached()) out |= DSI_DEBUGGER;
  if (mask & (DSI_ROOT_FILES_HIGH | DSI_ROOT_FILES_LOW)) {
    out |= root_files() & mask;
  }
  if ((mask & DSI_ROOT_MOUNTS) && root_mounts()) out |= DSI_ROOT_MOUNTS;
#elif defined(__APPLE__)
  if ((mask & DSI_DEBUGGER) && tracer_attached()) out |= DSI_DEBUGGER;
  if ((mask & DSI_DYLD_INJECTION) && injected_image_loaded()) out |= DSI_DYLD_INJECTION;
  if ((mask & DSI_JB_FILES) && jailbreak_files()) out |= DSI_JB_FILES;
#else
  (void)mask;
#endif
  return out;
}

DSI_EXPORT uint32_t dsi_abi_version(void) { return DSI_ABI_VERSION; }
