package com.devamitkumartiwari.device_safety_info.features.app_integrity

import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireContext
import com.devamitkumartiwari.device_safety_info.generated.FlutterError
import com.devamitkumartiwari.device_safety_info.generated.IntegrityHostApi
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Play Integrity (Android). The Play Integrity library is compileOnly: apps opt in by adding
 * `com.google.android.play:integrity`. Without it every call reports UNSUPPORTED. App Attest and
 * DeviceCheck are iOS only and report UNSUPPORTED here.
 */
class IntegrityHostApiImpl(private val host: PluginHost) : IntegrityHostApi, Disposable {

    private val libraryPresent: Boolean by lazy {
        try {
            Class.forName("com.google.android.play.core.integrity.IntegrityManagerFactory")
            true
        } catch (_: ClassNotFoundException) {
            false
        } catch (_: LinkageError) {
            false
        }
    }

    private var client: PlayIntegrityClient? = null

    private fun client(): PlayIntegrityClient {
        if (!libraryPresent) {
            throw FlutterError(
                "UNSUPPORTED",
                "Play Integrity library not found. Add " +
                    "implementation(\"com.google.android.play:integrity:<version>\") to your app.",
            )
        }
        return client ?: PlayIntegrityClient(host.requireContext()).also { client = it }
    }

    override fun isPlayIntegrityAvailable(): Boolean = libraryPresent

    override suspend fun preparePlayIntegrity(cloudProjectNumber: Long) {
        val c = client()
        suspendCancellableCoroutine { cont ->
            c.prepare(
                cloudProjectNumber,
                { cont.resume(Unit) },
                { code, msg -> cont.resumeWithException(FlutterError(code, msg)) },
            )
        }
    }

    override suspend fun requestPlayIntegrityToken(requestHash: String): String {
        val c = client()
        return suspendCancellableCoroutine { cont ->
            c.request(
                requestHash,
                { token -> cont.resume(token) },
                { code, msg -> cont.resumeWithException(FlutterError(code, msg)) },
            )
        }
    }

    override fun isAppAttestSupported(): Boolean = false

    override suspend fun generateAppAttestKey(): String = unsupported("App Attest")

    override suspend fun attestAppAttestKey(keyId: String, challenge: String): String =
        unsupported("App Attest")

    override suspend fun generateAppAttestAssertion(keyId: String, clientData: String): String =
        unsupported("App Attest")

    override fun isDeviceCheckSupported(): Boolean = false

    override suspend fun generateDeviceCheckToken(): String = unsupported("DeviceCheck")

    private fun unsupported(what: String): Nothing =
        throw FlutterError("UNSUPPORTED", "$what is only available on iOS")

    override fun dispose() {
        client?.clear()
        client = null
    }
}
