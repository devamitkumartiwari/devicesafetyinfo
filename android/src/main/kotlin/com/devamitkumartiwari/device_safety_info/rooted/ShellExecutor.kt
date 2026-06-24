package com.devamitkumartiwari.device_safety_info.rooted

import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

object ShellExecutor {

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

            val finished = process.waitFor(200, TimeUnit.MILLISECONDS)
            if (!finished) process.destroyForcibly()
            stdoutThread.join(50)
            stdoutLine != null
        } catch (_: Exception) {
            false
        } finally {
            process?.destroyForcibly()
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
            process.waitFor(200, TimeUnit.MILLISECONDS)
            BufferedReader(InputStreamReader(process.inputStream)).use { it.readLine() }
        } catch (_: Exception) {
            null
        } finally {
            process?.destroyForcibly()
        }
    }
}
