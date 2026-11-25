package com.devamitkumartiwari.device_safety_info.features.posture

import android.content.Context
import android.provider.Settings
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal

/** Turns the individual posture checks into signal reports. All of these read Settings or
 *  PackageManager, so callers run them on the BackgroundRunner. */
object PostureReports {

    fun developerMode(context: Context): RiskReport {
        val signals = mutableListOf<RiskSignal>()
        if (DevelopmentModeCheck.isDevMode(context)) {
            signals += RiskSignal("developer_mode.enabled", highRisk = false)
        }
        val adb = try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) != 0
        } catch (_: Exception) {
            false
        }
        if (adb) signals += RiskSignal("developer_mode.adb_enabled", highRisk = false)
        return RiskReport(signals)
    }

    fun screenLock(context: Context): RiskReport =
        RiskReport.of(!ScreenLockCheck.isDeviceScreenLocked(context), "screen_lock.none", highRisk = true)

    fun storeInstall(context: Context): RiskReport =
        RiskReport.of(
            !StoreInstallCheck.isInstalledFromStore(context),
            "store_install.unknown_installer",
            highRisk = false,
        )

    fun externalStorage(context: Context): RiskReport =
        RiskReport.of(
            ExternalStorageCheck.isExternalStorage(context),
            "external_storage.installed",
            highRisk = false,
        )

    fun unknownSources(context: Context): RiskReport =
        RiskReport.of(
            UnknownSourcesCheck.isUnknownSourcesEnabled(context),
            "unknown_sources.allowed",
            highRisk = false,
        )

    /** Setting value 1 = enabled, -1 = disabled, anything else = unknown. */
    fun playProtect(context: Context): RiskReport = when (PlayProtectStatusCheck.getStatus(context)) {
        1 -> RiskReport.EMPTY
        -1 -> RiskReport(listOf(RiskSignal("play_protect.disabled", highRisk = true)))
        else -> RiskReport(listOf(RiskSignal("play_protect.unknown", highRisk = false)))
    }
}
