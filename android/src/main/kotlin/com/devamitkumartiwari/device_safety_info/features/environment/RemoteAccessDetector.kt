package com.devamitkumartiwari.device_safety_info.features.environment

import android.content.Context
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.core.SystemApps
import com.devamitkumartiwari.device_safety_info.features.accessibility.AccessibilityAbuseDetector
import com.devamitkumartiwari.device_safety_info.features.malware.MalwarePackageDetector
import com.devamitkumartiwari.device_safety_info.generated.Signatures

/**
 * Remote-control apps (AnyDesk, TeamViewer QuickSupport, RustDesk, AirDroid, ...), the main tool
 * of "support call" scams. Installed alone is low risk (IT staff use them too); an enabled
 * accessibility service belonging to one is high risk, because that is what lets the remote
 * side tap and type on this phone. Allowlisting happens in Dart.
 */
object RemoteAccessDetector {

    fun report(context: Context): RiskReport {
        val installed = Signatures.remoteAccessPackages.filter {
            MalwarePackageDetector.isPackageInstalled(context, it)
        }
        val services = try {
            AccessibilityAbuseDetector.enabledServices(context).map { it.id }
        } catch (_: Exception) {
            emptyList()
        }
        return RiskReport(signals(installed, services, Signatures.remoteAccessPackages))
    }

    /**
     * [installed]: remote-access packages present. [enabledServices]: component ids of enabled
     * accessibility services. [knownPackages]: the remote-access package list.
     */
    fun signals(
        installed: List<String>,
        enabledServices: List<String>,
        knownPackages: List<String>,
    ): List<RiskSignal> {
        val controlling = enabledServices
            .map { SystemApps.packageOf(it) }
            .filter { it in knownPackages }
            .toSet()
        return controlling.map { RiskSignal("remote_access.control_service:$it", highRisk = true) } +
            installed.filter { it !in controlling }
                .map { RiskSignal("remote_access.app_installed:$it", highRisk = false) }
    }
}
