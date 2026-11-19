package com.devamitkumartiwari.device_safety_info.features.app_integrity

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode

/**
 * The ONLY class in the plugin that references Play Integrity types. The library is a
 * `compileOnly` dependency (opt-in for consuming apps), so this class must never be loaded unless
 * [PlayIntegrityFeature] has confirmed the library is on the classpath — otherwise the JVM would
 * throw `NoClassDefFoundError` while resolving these imports.
 *
 * Produces opaque tokens only. Decoding/verification must happen on the app's server via Google's
 * `decodeIntegrityToken` API — never on-device.
 */
internal class PlayIntegrityClient(private val context: Context) {

    private var provider: StandardIntegrityTokenProvider? = null

    fun prepare(
        cloudProjectNumber: Long,
        onOk: () -> Unit,
        onErr: (String, String?) -> Unit,
    ) {
        IntegrityManagerFactory.createStandard(context)
            .prepareIntegrityToken(
                PrepareIntegrityTokenRequest.builder()
                    .setCloudProjectNumber(cloudProjectNumber)
                    .build()
            )
            .addOnSuccessListener { provider = it; onOk() }
            .addOnFailureListener { onErr(mapError(it), it.message) }
    }

    fun request(
        requestHash: String,
        onOk: (String) -> Unit,
        onErr: (String, String?) -> Unit,
    ) {
        val p = provider ?: run {
            onErr("NOT_PREPARED", "Call AppIntegrity.preparePlayIntegrity() first")
            return
        }
        p.request(StandardIntegrityTokenRequest.builder().setRequestHash(requestHash).build())
            .addOnSuccessListener { onOk(it.token()) }
            .addOnFailureListener {
                val code = mapError(it)
                // The provider is no longer usable; Dart must call preparePlayIntegrity again.
                if (code == "PROVIDER_INVALID") provider = null
                onErr(code, it.message)
            }
    }

    fun clear() {
        provider = null
    }

    private fun mapError(e: Exception): String {
        if (e !is StandardIntegrityException) return "UNKNOWN"
        return when (e.errorCode) {
            StandardIntegrityErrorCode.API_NOT_AVAILABLE,
            StandardIntegrityErrorCode.PLAY_STORE_NOT_FOUND,
            StandardIntegrityErrorCode.PLAY_SERVICES_NOT_FOUND,
            StandardIntegrityErrorCode.PLAY_SERVICES_VERSION_OUTDATED,
            StandardIntegrityErrorCode.PLAY_STORE_VERSION_OUTDATED -> "PLAY_SERVICES_UNAVAILABLE"
            StandardIntegrityErrorCode.NETWORK_ERROR -> "NETWORK"
            StandardIntegrityErrorCode.TOO_MANY_REQUESTS -> "TOO_MANY_REQUESTS"
            StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID -> "PROVIDER_INVALID"
            StandardIntegrityErrorCode.CLOUD_PROJECT_NUMBER_IS_INVALID,
            StandardIntegrityErrorCode.REQUEST_HASH_TOO_LONG -> "INVALID_INPUT"
            else -> "PLAY_INTEGRITY_${e.errorCode}"
        }
    }
}
