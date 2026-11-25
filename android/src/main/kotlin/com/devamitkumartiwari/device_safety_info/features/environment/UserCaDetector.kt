package com.devamitkumartiwari.device_safety_info.features.environment

import android.content.Context
import com.devamitkumartiwari.device_safety_info.core.RiskReport
import com.devamitkumartiwari.device_safety_info.core.RiskSignal
import com.devamitkumartiwari.device_safety_info.features.vpn.VpnReport
import java.security.KeyStore
import java.security.cert.X509Certificate

/**
 * User-installed CA certificates, which let tools like Charles, Burp or mitmproxy decrypt HTTPS.
 * Android 7+ apps ignore user CAs unless their network security config opts in, so a user CA
 * alone is low risk. A user CA together with an active VPN or proxy (traffic actually being
 * routed somewhere) is high risk.
 */
object UserCaDetector {

    fun report(context: Context): RiskReport {
        val names = try {
            val store = KeyStore.getInstance("AndroidCAStore").apply { load(null) }
            userAliases(store.aliases().toList()).map { alias ->
                (store.getCertificate(alias) as? X509Certificate)?.let { commonName(it) } ?: alias
            }
        } catch (_: Exception) {
            emptyList()
        }
        val routed = try {
            VpnReport.evaluate(context).signals.isNotEmpty()
        } catch (_: Exception) {
            false
        }
        return RiskReport(signals(names, routed))
    }

    /** AndroidCAStore aliases of user-installed certificates (`user:...`). */
    fun userAliases(aliases: List<String>): List<String> = aliases.filter { it.startsWith("user:") }

    fun signals(userCaNames: List<String>, trafficRouted: Boolean): List<RiskSignal> = buildList {
        if (userCaNames.isNotEmpty() && trafficRouted) {
            add(RiskSignal("mitm.user_ca_with_proxy", highRisk = true))
        }
        userCaNames.forEach { add(RiskSignal("mitm.user_ca:$it", highRisk = false)) }
    }

    private fun commonName(cert: X509Certificate): String? =
        cert.subjectX500Principal.name.split(',')
            .map { it.trim() }
            .firstOrNull { it.startsWith("CN=") }
            ?.removePrefix("CN=")
}
