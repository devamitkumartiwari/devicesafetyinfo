package com.devamitkumartiwari.device_safety_info.features.app_integrity

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import com.devamitkumartiwari.device_safety_info.generated.SigningInfoMsg
import java.security.MessageDigest

/**
 * Reads the certificates this APK is signed with, for the tampering check. A repackaged app
 * (decompiled, modified, re-signed) can't carry the original certificate, so comparing the
 * digest against the developer's known certificate detects it. The comparison happens in Dart
 * against `DeviceSafetyConfig.expectedSigningCertificates`.
 */
object SigningInfoReader {

    fun read(context: Context): SigningInfoMsg =
        SigningInfoMsg(
            certificateSha256 = signatures(context).map { sha256Hex(it.toByteArray()) }.distinct(),
            hasProvisioningProfile = false,
            teamId = null,
        )

    /** Lowercase hex SHA-256 of [bytes]. */
    fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    private fun signatures(context: Context): List<Signature> {
        val pm = context.packageManager
        val pkg = context.packageName
        if (Build.VERSION.SDK_INT >= 28) {
            val flag = PackageManager.GET_SIGNING_CERTIFICATES
            val info = if (Build.VERSION.SDK_INT >= 33) {
                pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(flag.toLong()))
            } else {
                pm.getPackageInfo(pkg, flag)
            }
            val signing = info.signingInfo ?: return emptyList()
            // With key rotation the history holds the current certificate and its verified
            // ancestors; an attacker can't forge that lineage without the original key.
            return if (signing.hasMultipleSigners()) {
                signing.apkContentsSigners.toList()
            } else {
                signing.signingCertificateHistory.toList()
            }
        }
        @Suppress("DEPRECATION")
        val info = pm.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
        @Suppress("DEPRECATION")
        return info.signatures?.toList().orEmpty()
    }
}
