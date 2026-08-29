package com.devamitkumartiwari.device_safety_info.rooted

import android.os.Build
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

object ShellExecutor {

    // Process.waitFor(long, TimeUnit) and Process.destroyForcibly() are API 26+.
    // These helpers keep the same bounded-wait behavior on API 24/25 by polling
    // exitValue() instead of falling back to an unbounded waitFor().
    private fun waitForWithTimeout(process: Process, timeoutMs: Long): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
        }
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            try {
                process.exitValue()
                return true
            } catch (_: IllegalThreadStateException) {
                Thread.sleep(10)
            }
        }
        return try {
            process.exitValue()
            true
        } catch (_: IllegalThreadStateException) {
            false
        }
    }

    private fun destroyProcess(process: Process?) {
        process ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            process.destroyForcibly()
        } else {
            process.destroy()
        }
    }

    fun executeCommand(command: String): Boolean {
        val parts = command.trim().split("\\s+".toRegex())
        var process: Process? = null
        return try {
            process = ProcessBuilder(parts).redirectErrorStream(false).start()

            // Drain stdout on a daemon thread concurrently with waitFor so a full
            // output buffer can't deadlock the process before the timeout fires.
            var stdoutLine: String? = null
            val stdoutThread = Thread {
                process.inputStream.bufferedReader().use { r ->
                    stdoutLine = r.readLine()
                    r.forEachLine { } // drain remaining lines
                }
            }.also { it.isDaemon = true; it.start() }

            Thread { process.errorStream.use { it.readBytes() } }
                .also { it.isDaemon = true; it.start() }

            val finished = waitForWithTimeout(process, 200)
            if (!finished) destroyProcess(process)
            stdoutThread.join(50)
            stdoutLine != null
        } catch (_: Exception) {
            false
        } finally {
            destroyProcess(process)
        }
    }

    fun getSystemProperty(prop: String): String? {
        // Read from Android's internal property cache via reflection — zero cost,
        // no shell spawn. Falls back to `getprop` only if reflection is restricted.
        try {
            val clazz = Class.forName("android.os.SystemProperties")
            val get = clazz.getMethod("get", String::class.java, String::class.java)
            val value = get.invoke(null, prop, "") as? String
            if (!value.isNullOrEmpty()) return value
        } catch (_: Exception) {}

        var process: Process? = null
        return try {
            process = ProcessBuilder("getprop", prop).redirectErrorStream(true).start()
            Thread { process.errorStream.use { it.readBytes() } }
                .also { it.isDaemon = true; it.start() }
            waitForWithTimeout(process, 200)
            BufferedReader(InputStreamReader(process.inputStream)).use { it.readLine() }
        } catch (_: Exception) {
            null
        } finally {
            destroyProcess(process)
        }
    }
}
