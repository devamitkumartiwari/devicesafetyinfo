package com.devamitkumartiwari.device_safety_info.rooted

import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * A utility for executing shell commands on the device.
 *
 * This object provides a simple interface for running shell commands and retrieving their output,
 * which is primarily used for root detection checks. It is designed to be safe and non-blocking.
 */
object ShellExecutor {

    /**
     * Executes a given shell command and checks if it produces any standard output.
     *
     * This method is useful for commands like `which su`, where any output indicates that
     * the executable was found in the system's PATH. It includes a short timeout to prevent
     * the check from hanging.
     *
     * @param command The shell command to execute (e.g., "which su").
     * @return `true` if the command produces at least one line of output, `false` otherwise.
     */
    fun executeCommand(command: String): Boolean {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec(command)
            // Wait for the process to complete, with a short timeout to prevent blocking indefinitely.
            process.waitFor(50, TimeUnit.MILLISECONDS)
            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                // If readLine() is not null, it means the command produced some output.
                reader.readLine() != null
            }
        } catch (e: Exception) {
            // Exceptions (e.g., IOException, InterruptedException) are treated as command failure.
            false
        } finally {
            // Ensure the process is destroyed to free up system resources.
            process?.destroy()
        }
    }

    /**
     * Retrieves a system property by executing the `getprop` shell command.
     *
     * @param prop The name of the system property to retrieve (e.g., "ro.build.tags").
     * @return The value of the property as a String, or `null` if it cannot be read or an error occurs.
     */
    fun getSystemProperty(prop: String): String? {
        var process: Process? = null
        return try {
            process = Runtime.getRuntime().exec("getprop $prop")
            process.waitFor(50, TimeUnit.MILLISECONDS)
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
