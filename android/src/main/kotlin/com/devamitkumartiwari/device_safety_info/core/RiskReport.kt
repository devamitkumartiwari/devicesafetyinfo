package com.devamitkumartiwari.device_safety_info.core

import com.devamitkumartiwari.device_safety_info.generated.CheckReportMsg
import com.devamitkumartiwari.device_safety_info.generated.SignalLevelMsg
import com.devamitkumartiwari.device_safety_info.generated.SignalMsg

/**
 * One indicator found by a check.
 *
 * @property id `<check>.<signal>` optionally followed by `:<detail>`, e.g.
 *   `root.su_executable:/system/xbin/su`. The part before `:` is what apps override by.
 * @property highRisk `true` for evidence that essentially never appears on a normal device.
 */
data class RiskSignal(val id: String, val highRisk: Boolean) {
    fun toMsg(): SignalMsg = SignalMsg(id, if (highRisk) SignalLevelMsg.HIGH else SignalLevelMsg.LOW)
}

/** Everything one check found. Policy is applied in Dart, not here. */
data class RiskReport(val signals: List<RiskSignal>, val supported: Boolean = true) {
    val isHighRisk: Boolean get() = signals.any { it.highRisk }

    fun toMsg(): CheckReportMsg = CheckReportMsg(signals.map { it.toMsg() }, supported)

    companion object {
        val EMPTY = RiskReport(emptyList())
        val UNSUPPORTED = RiskReport(emptyList(), supported = false)

        /** A report with a single signal when [condition] holds, otherwise empty. */
        fun of(condition: Boolean, id: String, highRisk: Boolean): RiskReport =
            if (condition) RiskReport(listOf(RiskSignal(id, highRisk))) else EMPTY
    }
}
