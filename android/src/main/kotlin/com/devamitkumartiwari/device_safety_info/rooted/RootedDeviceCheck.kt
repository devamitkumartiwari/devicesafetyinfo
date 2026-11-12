package com.devamitkumartiwari.device_safety_info.rooted

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.RiskReport

/**
 * A utility to determine if the device is rooted.
 *
 * Every checker reports what it found as [RiskSignal]s tagged high- or low-risk:
 *  - Root-related files (`su` binaries, Magisk, Superuser) — [RootFilesChecker].
 *  - Root-related binaries in `PATH` — [RootCommandsChecker].
 *  - System properties that indicate an insecure or modified build — [SystemPropsChecker].
 *
 * Only high-risk signals make [isRootedDevice] return `true`; low-risk signals are reported by
 * [evaluate] so the app can decide its own policy (log, warn, step-up auth) without blocking
 * users of stock firmware that happens to ship e.g. `busybox`.
 */
object RootedDeviceCheck {

    /** Runs every checker and returns all indicators found. A failing checker contributes none. */
    fun evaluate(): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        for (checker in listOf<() -> List<RiskSignal>>(
            RootFilesChecker::signals,
            RootCommandsChecker::signals,
            SystemPropsChecker::signals,
        )) {
            try {
                signals += checker()
            } catch (_: Exception) {
            }
        }
        return RiskReport(signals.distinctBy { it.id })
    }

    /** `true` only when at least one high-risk root indicator is present. */
    fun isRootedDevice(): Boolean = evaluate().isHighRisk
}
