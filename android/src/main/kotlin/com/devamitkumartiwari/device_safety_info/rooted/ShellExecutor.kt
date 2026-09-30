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
            // stderr is merged into stdout, and everything below runs on the calling
            // thread inside this try, so a stream closed by destroyProcess can't escape.
            process = ProcessBuilder("getprop", prop).redirectErrorStream(true).start()
            waitForWithTimeout(process, 200)
            BufferedReader(InputStreamReader(process.inputStream)).use { it.readLine() }
        } catch (_: Exception) {
            null
        } finally {
            destroyProcess(process)
        }
    }
}
