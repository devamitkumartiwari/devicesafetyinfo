package com.devamitkumartiwari.device_safety_info.core

import android.os.Build
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * Reads Android system properties.
 *
 * The normal path is reflection on `android.os.SystemProperties.get`, which reads the in-process
 * property area: no subprocess, cheap enough for the main thread. An empty string from it is a
 * real answer (the property isn't set), so it maps to `null` without a fallback. A `getprop`
 * subprocess is spawned only if reflection itself is unavailable.
 */
internal object SystemProps {

    private const val GETPROP_TIMEOUT_MS = 200L

    private val reflectedGet: java.lang.reflect.Method? by lazy {
        try {
            Class.forName("android.os.SystemProperties")
                .getMethod("get", String::class.java, String::class.java)
        } catch (_: Throwable) {
            null
        }
    }

    /** The value of [name], or `null` if it's unset or can't be read. */
    fun get(name: String): String? {
        val method = reflectedGet
        if (method != null) {
            try {
                return (method.invoke(null, name, "") as? String)?.takeIf { it.isNotEmpty() }
            } catch (_: Throwable) {
                // Fall through to getprop.
            }
        }
        return getprop(name)
    }

    /**
     * Reads [name] through a `getprop` subprocess, bounded by [GETPROP_TIMEOUT_MS]. Returns `null`
     * when the process doesn't finish in time instead of blocking on its output.
     */
    private fun getprop(name: String): String? {
        var process: Process? = null
        return try {
            process = ProcessBuilder("getprop", name).redirectErrorStream(true).start()
            if (!waitFor(process, GETPROP_TIMEOUT_MS)) return null
            BufferedReader(InputStreamReader(process.inputStream)).use { it.readLine() }
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        } finally {
            destroy(process)
        }
    }

    // Process.waitFor(long, TimeUnit) and destroyForcibly() are API 26+. On API 24/25 poll
    // exitValue() so the wait stays bounded.
    private fun waitFor(process: Process, timeoutMs: Long): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return process.waitFor(timeoutMs, TimeUnit.MILLISECONDS)
        }
        val deadline = System.currentTimeMillis() + timeoutMs
        while (true) {
            try {
                process.exitValue()
                return true
            } catch (_: IllegalThreadStateException) {
                if (System.currentTimeMillis() >= deadline) return false
                Thread.sleep(10)
            }
        }
    }

    private fun destroy(process: Process?) {
        process ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            process.destroyForcibly()
        } else {
            process.destroy()
        }
    }
}
