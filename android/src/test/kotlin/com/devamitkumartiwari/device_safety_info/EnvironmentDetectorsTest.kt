package com.devamitkumartiwari.device_safety_info

import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.features.environment.CloneDetector
import com.devamitkumartiwari.device_safety_info.features.environment.MockLocationDetector
import com.devamitkumartiwari.device_safety_info.features.environment.RemoteAccessDetector
import com.devamitkumartiwari.device_safety_info.features.environment.UserCaDetector
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CloneDetectorTest {
    private val own = "com.example.bank"

    @Test
    fun normalInstallIsClean() {
        assertEquals(emptyList(), CloneDetector.classify("/data/user/0/$own", own))
        assertEquals(emptyList(), CloneDetector.classify("/data/data/$own", own))
        assertEquals(emptyList(), CloneDetector.classify("/mnt/expand/1234-abcd/user/0/$own", own))
    }

    @Test
    fun secondaryUserIsLowRisk() {
        assertEquals(
            listOf(RiskSignal("clone.secondary_user", false)),
            CloneDetector.classify("/data/user/95/$own", own),
        )
    }

    @Test
    fun virtualContainerIsHighRisk() {
        val s = CloneDetector.classify("/data/user/0/com.lbe.parallel.intl/parallel_intl/0/$own", own)
        assertEquals(listOf(RiskSignal("clone.virtual_container:com.lbe.parallel.intl", true)), s)
    }

    @Test
    fun unknownLayoutIsTreatedAsContainer() {
        val s = CloneDetector.classify("/storage/emulated/0/virtual/$own", own)
        assertTrue(s.single().highRisk)
    }
}

class RemoteAccessDetectorTest {
    private val known = listOf("com.anydesk.anydeskandroid", "com.rustdesk.rustdesk")

    @Test
    fun controllingServiceIsHighAndNotDuplicatedAsInstalled() {
        val s = RemoteAccessDetector.signals(
            installed = listOf("com.anydesk.anydeskandroid", "com.rustdesk.rustdesk"),
            enabledServices = listOf(
                "com.anydesk.anydeskandroid/com.anydesk.adcontrol.AccessibilityService",
                "com.google.android.marvin.talkback/.TalkBackService",
            ),
            knownPackages = known,
        )
        assertEquals(
            listOf(
                RiskSignal("remote_access.control_service:com.anydesk.anydeskandroid", true),
                RiskSignal("remote_access.app_installed:com.rustdesk.rustdesk", false),
            ),
            s,
        )
    }

    @Test
    fun nothingInstalled() {
        assertEquals(emptyList(), RemoteAccessDetector.signals(emptyList(), emptyList(), known))
    }
}

class MockLocationDetectorTest {
    @Test
    fun selectedIsHighInstalledIsLow() {
        val s = MockLocationDetector.signals(
            installed = listOf("com.lexa.fakegps", "ru.gavrikov.mocklocations"),
            selected = listOf("com.lexa.fakegps"),
            mockFix = true,
        )
        assertEquals(
            listOf(
                RiskSignal("location.mock_fix", true),
                RiskSignal("location.mock_app_selected:com.lexa.fakegps", true),
                RiskSignal("location.mock_app_installed:ru.gavrikov.mocklocations", false),
            ),
            s,
        )
    }
}

class UserCaDetectorTest {
    @Test
    fun onlyUserAliasesCount() {
        assertEquals(
            listOf("user:abc.0"),
            UserCaDetector.userAliases(listOf("system:1234.0", "user:abc.0")),
        )
    }

    @Test
    fun userCaIsHighOnlyWhenTrafficIsRouted() {
        assertEquals(
            listOf(RiskSignal("mitm.user_ca:Charles", false)),
            UserCaDetector.signals(listOf("Charles"), trafficRouted = false),
        )
        assertEquals(
            listOf(RiskSignal("mitm.user_ca_with_proxy", true), RiskSignal("mitm.user_ca:Charles", false)),
            UserCaDetector.signals(listOf("Charles"), trafficRouted = true),
        )
        assertEquals(emptyList(), UserCaDetector.signals(emptyList(), trafficRouted = true))
    }
}
