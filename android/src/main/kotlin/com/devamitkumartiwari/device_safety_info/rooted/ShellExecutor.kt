package com.devamitkumartiwari.device_safety_info.rooted

import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

object ShellExecutor {

    fun executeCommand(command: String): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(command)
            // Drain stderr on a background thread so a full stderr buffer can't
            // cause the process to block waiting for the consumer.
            val stderrThread = Thread { process.errorStream.use { it.readBytes() } }
            stderrThread.isDaemon = true
            stderrThread.start()

            // 200 ms gives slower devices enough time to locate the binary
            // while still keeping the check fast on real devices.
            process.waitFor(200, TimeUnit.MILLISECONDS)
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                reader.readLine() != null
            }
        } catch (e: Exception) {
            false
        } finally {
            process?.destroy()
        }
    }

    fun getSystemProperty(prop: String): String? {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec("getprop $prop")
            val stderrThread = Thread { process.errorStream.use { it.readBytes() } }
            stderrThread.isDaemon = true
            stderrThread.start()

            process.waitFor(200, TimeUnit.MILLISECONDS)
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                reader.readLine()
            }
        } catch (e: Exception) {
            null
        } finally {
            process?.destroy()
        }
    }
}
