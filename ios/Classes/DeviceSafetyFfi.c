#include <stdint.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/proc.h>

// Frida detection on iOS is fully handled by IOSSecuritySuite on the Swift side.
// This stub exists so the same Dart FFI symbol names resolve on both platforms.
__attribute__((visibility("default")))
int32_t dsi_check_frida_maps(void) {
    return 0;
}

// Detects if a debugger is attached using the sysctl P_TRACED flag.
// This is a low-level kernel check that is harder to bypass than
// IOSSecuritySuite's high-level check alone.
__attribute__((visibility("default")))
int32_t dsi_is_debugger_attached(void) {
    int mib[4];
    struct kinfo_proc info;
    size_t size = sizeof(info);

    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC;
    mib[2] = KERN_PROC_PID;
    mib[3] = getpid();

    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return 0;
    }
    return ((info.kp_proc.p_flag & P_TRACED) != 0) ? 1 : 0;
}

// Jailbreak file detection on iOS is fully handled by IOSSecuritySuite.
__attribute__((visibility("default")))
int32_t dsi_check_root_files(void) {
    return 0;
}
