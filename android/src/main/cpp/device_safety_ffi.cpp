#include <cstdint>
#include <cstdio>
#include <cstring>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <poll.h>

extern "C" {

// Attempts a non-blocking TCP connect to Frida's default server ports.
// Frida can hide from /proc/self/maps by using a renamed binary, but it
// cannot hide the listening socket on the host.
static int32_t check_frida_ports() {
    const int ports[] = {27042, 27043};
    constexpr int num_ports = 2;

    for (int p = 0; p < num_ports; p++) {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock == -1) continue;

        int flags = fcntl(sock, F_GETFL, 0);
        if (flags == -1) flags = 0;
        fcntl(sock, F_SETFL, flags | O_NONBLOCK);

        struct sockaddr_in addr = {};
        addr.sin_family      = AF_INET;
        addr.sin_port        = htons(ports[p]);
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

        int rc = connect(sock, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr));
        if (rc == 0) {
            close(sock);
            return 1;
        }

        if (errno == EINPROGRESS) {
            // poll() has no FD_SETSIZE limit, unlike select() + FD_SET which
            // overflows and crashes (SIGABRT via FORTIFY) when sock >= 1024.
            struct pollfd pfd = {};
            pfd.fd = sock;
            pfd.events = POLLOUT;
            if (poll(&pfd, 1, 50) > 0) { // 50 ms
                int err = 0;
                socklen_t len = sizeof(err);
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len);
                if (err == 0) {
                    close(sock);
                    return 1;
                }
            }
        }
        close(sock);
    }
    return 0;
}

// Scans /proc/self/maps for Frida-related library signatures AND checks
// whether Frida's server is listening on its default ports (27042/27043).
// The port check catches renamed Frida binaries that evade the maps scan.
__attribute__((visibility("default")))
int32_t dsi_check_frida_maps() {
    // Maps scan
    FILE* f = fopen("/proc/self/maps", "r");
    if (f) {
        const char* patterns[] = {
            "frida", "gum-js-loop", "gmain", "linjector",
            "frida-agent", "re.frida", "frida-gadget", "frida-server"
        };
        constexpr int num_patterns = 8;

        char line[512];
        while (fgets(line, sizeof(line), f)) {
            for (int i = 0; i < num_patterns; i++) {
                if (strstr(line, patterns[i]) != nullptr) {
                    fclose(f);
                    return 1;
                }
            }
        }
        fclose(f);
    }

    // Port scan — catches Frida even when maps scan is evaded
    return check_frida_ports();
}

// Checks /proc/self/status for a non-zero TracerPid, which indicates
// that a debugger process is currently attached to this process.
__attribute__((visibility("default")))
int32_t dsi_is_debugger_attached() {
    FILE* f = fopen("/proc/self/status", "r");
    if (!f) return 0;

    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "TracerPid:", 10) == 0) {
            int tracer_pid = 0;
            sscanf(line + 10, "%d", &tracer_pid);
            fclose(f);
            return (tracer_pid != 0) ? 1 : 0;
        }
    }
    fclose(f);
    return 0;
}

// Checks for common root indicator files using the C-level stat() syscall.
// Using stat() directly is harder to hook than Java's File.exists().
__attribute__((visibility("default")))
int32_t dsi_check_root_files() {
    const char* root_paths[] = {
        "/system/xbin/su",
        "/system/bin/su",
        "/sbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/system/bin/magisk",
        "/sbin/magisk",
        "/data/adb/magisk",
        "/system/app/Superuser.apk",
        "/data/local/tmp/frida-server"
    };
    constexpr int num_paths = 10;

    struct stat st;
    for (int i = 0; i < num_paths; i++) {
        if (stat(root_paths[i], &st) == 0) {
            return 1;
        }
    }
    return 0;
}

} // extern "C"
