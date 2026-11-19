package com.devamitkumartiwari.device_safety_info

import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.generated.SignalLevelMsg
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RiskReportTest {

    @Test
    fun signalLevelsMapToPigeonLevels() {
        val msg = RiskReport(
            listOf(
                RiskSignal("root.su_executable:/sbin/su", highRisk = true),
                RiskSignal("root.busybox:/system/xbin/busybox", highRisk = false),
            ),
        ).toMsg()
        assertTrue(msg.supported)
        assertEquals(listOf(SignalLevelMsg.HIGH, SignalLevelMsg.LOW), msg.signals.map { it.level })
        assertEquals("root.su_executable:/sbin/su", msg.signals.first().id)
    }

    @Test
    fun highRiskIsAnyHighSignal() {
        assertFalse(RiskReport.EMPTY.isHighRisk)
        assertFalse(RiskReport(listOf(RiskSignal("a", false))).isHighRisk)
        assertTrue(RiskReport(listOf(RiskSignal("a", false), RiskSignal("b", true))).isHighRisk)
    }

    @Test
    fun ofBuildsAReportOnlyWhenTheConditionHolds() {
        assertEquals(RiskReport.EMPTY, RiskReport.of(false, "screen_lock.none", highRisk = true))
        val r = RiskReport.of(true, "screen_lock.none", highRisk = true)
        assertEquals(listOf(RiskSignal("screen_lock.none", true)), r.signals)
    }

    @Test
    fun unsupportedReportIsMarked() {
        assertFalse(RiskReport.UNSUPPORTED.toMsg().supported)
        assertTrue(RiskReport.UNSUPPORTED.toMsg().signals.isEmpty())
    }

    @Test
    fun signalIdsFollowTheCheckDotSignalConvention() {
        // Dart overrides match the part before ':'; every id must have a check prefix.
        val ids = listOf(
            "root.su_executable:/x", "root.manager_file:/x", "root.test_keys:test-keys",
            "emulator.hardware:ranchu", "hooking.frida_server:/x", "debugger.attached",
            "vpn.active", "screen_capture.mirroring", "play_protect.disabled",
        )
        val pattern = Regex("""^[a-z_]+\.[a-z_]+(:.*)?${'$'}""")
        ids.forEach { assertTrue(pattern.matches(it), it) }
    }
}
