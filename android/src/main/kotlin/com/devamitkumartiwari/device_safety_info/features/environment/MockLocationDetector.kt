package com.devamitkumartiwari.device_safety_info.features.environment

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Process
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.features.malware.MalwarePackageDetector
import com.devamitkumartiwari.device_safety_info.generated.Signatures

/**
 * GPS spoofing. High risk: a known mock-location app is selected as the device's mock location
 * provider (Developer options › Select mock location app), or the last known location is
 * marked as mock (checked only when the app already holds a location permission; the plugin
 * never asks for one). Low risk: a mock-location app is merely installed.
 */
object MockLocationDetector {

    fun report(context: Context): RiskReport {
        val installed = Signatures.mockLocationPackages.filter {
            MalwarePackageDetector.isPackageInstalled(context, it)
        }
        val selected = installed.filter { isMockLocationApp(context, it) }
        return RiskReport(signals(installed, selected, lastFixIsMock(context)))
    }

    fun signals(installed: List<String>, selected: List<String>, mockFix: Boolean): List<RiskSignal> =
        buildList {
            if (mockFix) add(RiskSignal("location.mock_fix", highRisk = true))
            selected.forEach { add(RiskSignal("location.mock_app_selected:$it", highRisk = true)) }
            installed.filter { it !in selected }
                .forEach { add(RiskSignal("location.mock_app_installed:$it", highRisk = false)) }
        }

    /** Whether [pkg] is allowed the mock-location app op, i.e. chosen in developer options. */
    private fun isMockLocationApp(context: Context, pkg: String): Boolean = try {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val uid = context.packageManager.getApplicationInfo(pkg, 0).uid
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, uid, pkg)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, uid, pkg)
        }
        mode == AppOpsManager.MODE_ALLOWED
    } catch (_: Exception) {
        false
    }

    private fun lastFixIsMock(context: Context): Boolean {
        val granted = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ).any {
            context.checkPermission(it, Process.myPid(), Process.myUid()) ==
                PackageManager.PERMISSION_GRANTED
        }
        if (!granted) return false
        return try {
            val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            lm.getProviders(true).any { provider ->
                @Suppress("MissingPermission")
                val loc: Location? = lm.getLastKnownLocation(provider)
                loc != null && isMock(loc)
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun isMock(location: Location): Boolean = if (Build.VERSION.SDK_INT >= 31) {
        location.isMock
    } else {
        @Suppress("DEPRECATION")
        location.isFromMockProvider
    }
}
