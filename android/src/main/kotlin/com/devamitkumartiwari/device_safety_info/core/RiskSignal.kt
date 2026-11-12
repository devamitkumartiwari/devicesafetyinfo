package com.devamitkumartiwari.device_safety_info.core

/**
 * One indicator found by a tiered check (root, emulator, ...).
 *
 * @property id A stable, machine-readable description, e.g. `su:/system/xbin/su`,
 *   `prop:ro.boot.verifiedbootstate=orange` or `hardware:ranchu`. Safe to log for diagnostics.
 * @property highRisk `true` for indicators that essentially never appear on a normal device;
 *   `false` for indicators that also show up on unmodified OEM firmware.
 */
data class RiskSignal(val id: String, val highRisk: Boolean)

/** Result of a tiered check, split into high- and low-risk indicators. */
data class RiskReport(val signals: List<RiskSignal>) {
    val highRisk: List<String> get() = signals.filter { it.highRisk }.map { it.id }
    val lowRisk: List<String> get() = signals.filterNot { it.highRisk }.map { it.id }

    /** `"high"`, `"low"` or `"none"` — the most severe level any signal reached. */
    val level: String
        get() = when {
            highRisk.isNotEmpty() -> "high"
            lowRisk.isNotEmpty() -> "low"
            else -> "none"
        }

    val isHighRisk: Boolean get() = highRisk.isNotEmpty()

    /** Shape shared with the Dart `RiskCheckResult.fromMap` parser. */
    fun toMap(): Map<String, Any> = mapOf(
        "level" to level,
        "highRiskSignals" to highRisk,
        "lowRiskSignals" to lowRisk,
    )

    companion object {
        val EMPTY = RiskReport(emptyList())
    }
}
