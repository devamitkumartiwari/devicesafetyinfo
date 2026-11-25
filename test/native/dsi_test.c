// Unit tests for src/dsi.c, run on an Android device or emulator:
//
//   tool/run_native_tests.sh [abi]      # abi: arm64-v8a (default) or x86_64
//
// Includes dsi.c directly so the static parsers can be tested, then runs every check against
// the device it's on and prints which fired (a clean device should report 0x0).
#include "../../src/dsi.c"

#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/mman.h>

static int failures = 0;

#define EXPECT(cond)                                              \
  do {                                                            \
    if (!(cond)) {                                                \
      printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);      \
      failures++;                                                 \
    }                                                             \
  } while (0)

static void test_signature_decoding(void) {
  dsi_sig_iter it = {&DSI_SIG_SU_PATHS, 0};
  char entry[256];
  EXPECT(dsi_sig_next(&it, entry, sizeof(entry)));
  EXPECT(strcmp(entry, "/system/xbin/su") == 0);
  int count = 1;
  while (dsi_sig_next(&it, entry, sizeof(entry))) count++;
  EXPECT(count == 15);
  EXPECT(strcmp(entry, "/system/usr/we-need-root/su") == 0);
  // Exhausted iterators stay exhausted.
  EXPECT(!dsi_sig_next(&it, entry, sizeof(entry)));
  // Truncation never overflows.
  dsi_sig_iter small = {&DSI_SIG_SU_PATHS, 0};
  char tiny[5];
  EXPECT(dsi_sig_next(&small, tiny, sizeof(tiny)));
  EXPECT(strcmp(tiny, "/sys") == 0);
  // The encoded bytes never contain the plain path.
  EXPECT(memmem(DSI_SIG_SU_PATHS.data, DSI_SIG_SU_PATHS.len, "/system", 7) == NULL);
}

static void test_maps(void) {
  EXPECT(dsi_maps_line_frida(
      "7f1c000000-7f1c100000 r-xp 00000000 fd:01 123 /data/local/tmp/re.frida.server/frida-agent-64.so"));
  EXPECT(dsi_maps_line_frida("7f00-7f01 r-xp 0 00:00 0 /memfd:frida-agent-64.so (deleted)"));
  EXPECT(!dsi_maps_line_frida("7f00-7f01 r-xp 0 fd:01 9 /apex/com.android.runtime/lib64/bionic/libc.so"));
  // Thread names are not map entries.
  EXPECT(!dsi_maps_line_frida("7f00-7f01 r-xp 0 fd:01 9 /system/lib64/libgmain.so"));

  uintptr_t s, e;
  char perms[5];
  unsigned long long off;
  const char* path;
  EXPECT(dsi_parse_maps_line(
      "7a1b200000-7a1b2c8000 r-xp 00052000 fe:05 1234   /apex/com.android.runtime/lib64/bionic/libc.so",
      &s, &e, perms, &off, &path));
  EXPECT(s == (uintptr_t)0x7a1b200000ULL && e == (uintptr_t)0x7a1b2c8000ULL);
  EXPECT(strcmp(perms, "r-xp") == 0 && off == 0x52000);
  EXPECT(strcmp(path, "/apex/com.android.runtime/lib64/bionic/libc.so") == 0);
  EXPECT(dsi_ends_with(path, "/libc.so"));
  EXPECT(!dsi_ends_with("/system/lib64/libc.so.bak", "/libc.so"));
  EXPECT(!dsi_parse_maps_line("garbage", &s, &e, perms, &off, &path));
}

static void test_mounts(void) {
  // Magisk, KernelSU and APatch sources.
  EXPECT(dsi_mount_line_suspicious("magisk /system/bin tmpfs rw,seclabel,relatime 0 0"));
  EXPECT(dsi_mount_line_suspicious("KSU /system overlay ro,seclabel,lowerdir=/data/adb/modules/x 0 0"));
  EXPECT(dsi_mount_line_suspicious("APatch /vendor/bin overlay ro 0 0"));
  // Module overlay options.
  EXPECT(dsi_mount_line_suspicious(
      "overlay /product overlay ro,lowerdir=/data/adb/modules/m/product:/product 0 0"));
  // Read-write system partition.
  EXPECT(dsi_mount_line_suspicious("/dev/block/dm-0 /system ext4 rw,seclabel 0 0"));
  // tmpfs inside a system partition.
  EXPECT(dsi_mount_line_suspicious("tmpfs /system/xbin tmpfs rw,seclabel 0 0"));
  // Stock lines.
  EXPECT(!dsi_mount_line_suspicious("/dev/block/dm-0 / ext4 ro,seclabel,relatime 0 0"));
  EXPECT(!dsi_mount_line_suspicious("/dev/block/dm-3 /vendor erofs ro,seclabel 0 0"));
  EXPECT(!dsi_mount_line_suspicious("tmpfs /apex tmpfs rw,seclabel,nosuid 0 0"));
  EXPECT(!dsi_mount_line_suspicious("tmpfs /dev tmpfs rw,seclabel,nosuid 0 0"));
  EXPECT(!dsi_mount_line_suspicious("/dev/block/sda1 /data f2fs rw,lazytime 0 0"));
  EXPECT(!dsi_mount_line_suspicious("/dev/block/dm-0 /system ext4 rwx 0 0"));  // not "rw"
  EXPECT(!dsi_mount_line_suspicious("short line"));
}

static void test_threads(void) {
  int gmain = 0, gdbus = 0;
  EXPECT(dsi_comm_is_frida("gum-js-loop", &gmain, &gdbus));
  EXPECT(dsi_comm_is_frida("pool-frida", &gmain, &gdbus));
  EXPECT(!dsi_comm_is_frida("RenderThread", &gmain, &gdbus));
  EXPECT(!dsi_comm_is_frida("gmain", &gmain, &gdbus));
  EXPECT(gmain && !gdbus);
  EXPECT(!dsi_comm_is_frida("gdbus", &gmain, &gdbus));
  EXPECT(gmain && gdbus);
}

// Patches one byte of a libc function the way an inline hook would, and checks it's caught.
static void test_text_patch_detection(void) {
  size_t compared = 0;
  EXPECT(!libc_text_check(&compared));
  printf("libc text compared: %zu bytes\n", compared);
  EXPECT(compared > 100 * 1024);

  unsigned char* fn = (unsigned char*)dlsym(RTLD_DEFAULT, "ctermid");
  EXPECT(fn != NULL);
  if (!fn) return;
  long page = sysconf(_SC_PAGESIZE);
  void* base = (void*)((uintptr_t)fn & ~(uintptr_t)(page - 1));
  if (mprotect(base, (size_t)page, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
    printf("SKIP patch test: mprotect not allowed here\n");
    return;
  }
  unsigned char saved = fn[0];
  fn[0] = (unsigned char)(saved ^ 0xff);
  // While the page is still writable (rwxp)...
  int detected_rwx = libc_text_check(NULL);
  // ...and after restoring r-x, as an inline hook does once it's installed.
  mprotect(base, (size_t)page, PROT_READ | PROT_EXEC);
  int detected_rx = libc_text_check(NULL);
  mprotect(base, (size_t)page, PROT_READ | PROT_WRITE | PROT_EXEC);
  fn[0] = saved;
  mprotect(base, (size_t)page, PROT_READ | PROT_EXEC);
  EXPECT(detected_rwx);
  EXPECT(detected_rx);
  EXPECT(!libc_text_check(NULL));
}

static volatile int stop_thread = 0;

static void* fake_frida_thread(void* arg) {
  (void)arg;
  pthread_setname_np(pthread_self(), "gum-js-loop");
  while (!stop_thread) usleep(1000);
  return NULL;
}

// Recreates Frida's footprints one at a time and checks each detector sees them.
static void test_live_frida_indicators(void) {
  EXPECT(!frida_threads());
  pthread_t t;
  stop_thread = 0;
  EXPECT(pthread_create(&t, NULL, fake_frida_thread, NULL) == 0);
  usleep(50 * 1000);
  EXPECT(frida_threads());
  stop_thread = 1;
  pthread_join(t, NULL);
  EXPECT(!frida_threads());

  EXPECT(!frida_fds());
  const char* pipe_path = "/data/local/tmp/linjector-dsi-test";
  int fd = open(pipe_path, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
  EXPECT(fd >= 0);
  EXPECT(frida_fds());
  close(fd);
  unlink(pipe_path);
  EXPECT(!frida_fds());

  EXPECT(!frida_port_open());
  int server = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons(27042);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  int one = 1;
  setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  if (bind(server, (struct sockaddr*)&addr, sizeof(addr)) == 0 && listen(server, 1) == 0) {
    EXPECT(frida_port_open());
  } else {
    printf("SKIP port test: can't listen on 27042\n");
  }
  close(server);
}

int main(void) {
  test_text_patch_detection();
  test_live_frida_indicators();
  test_signature_decoding();
  test_maps();
  test_mounts();
  test_threads();

  uint32_t bits = dsi_collect_signals(DSI_ALL_CHECKS);
  printf("device: dsi_collect_signals(ALL) = 0x%x\n", bits);
  printf("  frida_maps=%d frida_threads=%d frida_fds=%d frida_port=%d text_patched=%d\n",
         !!(bits & DSI_FRIDA_MAPS), !!(bits & DSI_FRIDA_THREADS), !!(bits & DSI_FRIDA_FDS),
         !!(bits & DSI_FRIDA_PORT), !!(bits & DSI_TEXT_PATCHED));
  printf("  debugger=%d root_high=%d root_low=%d root_mounts=%d\n", !!(bits & DSI_DEBUGGER),
         !!(bits & DSI_ROOT_FILES_HIGH), !!(bits & DSI_ROOT_FILES_LOW),
         !!(bits & DSI_ROOT_MOUNTS));
  EXPECT(dsi_abi_version() == DSI_ABI_VERSION);

  printf(failures ? "%d FAILED\n" : "ALL PASSED\n", failures);
  return failures ? 1 : 0;
}
