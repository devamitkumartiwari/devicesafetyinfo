package com.devamitkumartiwari.device_safety_info.features.root

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.RiskReport

/**
 * Root detection on the JVM side.
 *
 * Every checker reports what it found as [RiskSignal]s tagged high- or low-risk:
 *  - Root-related files (`su` binaries, Magisk, Superuser) — [RootFilesChecker].
 *  - Root-related binaries in `PATH` — [RootCommandsChecker].
 *  - System properties that indicate an insecure or modified build — [SystemPropsChecker].
 *
 * The Dart policy decides what counts as "rooted"; under the standard policy only high-risk
 * signals do, so low-risk ones (a stock `busybox`, an unlocked bootloader) never block users.
 */
object RootedDeviceCheck {

    /** Thrown when every checker failed, so Dart reports an error instead of a clean result. */
    class AllCheckersFailed(cause: Throwable) : RuntimeException("Every root checker failed", cause)

    private val checkers: List<Pair<String, () -> List<RiskSignal>>> = listOf(
        "files" to { RootFilesChecker.signals() },
        "commands" to { RootCommandsChecker.signals() },
        "props" to { SystemPropsChecker.signals() },
    )

    /** Runs every checker on this device. */
    fun evaluate(): RiskReport = evaluate(checkers)

    /**
     * Runs [checkers] and returns every indicator found.
     *
     * A checker that throws doesn't silently count as clean: it adds a low-risk
     * `root.checker_error:<name>` signal (a hook that makes `File.exists` throw is a known
     * bypass). If every checker throws, [AllCheckersFailed] is thrown so the configured fail
     * mode applies.
     */
    fun evaluate(checkers: List<Pair<String, () -> List<RiskSignal>>>): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        var failures = 0
        var firstFailure: Throwable? = null
        for ((name, checker) in checkers) {
            try {
                signals += checker()
            } catch (e: Exception) {
                failures++
                if (firstFailure == null) firstFailure = e
                signals += RiskSignal("root.checker_error:$name", highRisk = false)
            }
        }
        if (checkers.isNotEmpty() && failures == checkers.size) {
            throw AllCheckersFailed(firstFailure!!)
        }
        return RiskReport(signals.distinctBy { it.id })
    }
}
