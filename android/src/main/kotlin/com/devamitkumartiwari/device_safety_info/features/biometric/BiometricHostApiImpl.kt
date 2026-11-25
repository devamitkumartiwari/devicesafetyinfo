package com.devamitkumartiwari.device_safety_info.features.biometric

import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import com.devamitkumartiwari.device_safety_info.core.requireActivity
import com.devamitkumartiwari.device_safety_info.features.device_key.AndroidKeys
import com.devamitkumartiwari.device_safety_info.generated.BiometricHostApi
import com.devamitkumartiwari.device_safety_info.generated.BiometricKeyStateMsg
import com.devamitkumartiwari.device_safety_info.generated.DeviceKeyInfoMsg
import com.devamitkumartiwari.device_safety_info.generated.FlutterError
import java.security.Signature
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Biometric-approved actions. The approval is a signature made by a key the Keystore releases
 * only after a strong biometric match (the framework `BiometricPrompt` with a `CryptoObject`), so
 * hooking the "authentication succeeded" callback can't fake it. Keys are invalidated when a new
 * fingerprint or face is enrolled. Needs Android 10 (API 29) or later.
 */
class BiometricHostApiImpl(
    private val host: PluginHost,
    private val bg: BackgroundRunner,
) : BiometricHostApi {

    private fun name(alias: String) = AndroidKeys.alias("biometric", alias)

    private fun requireSupported() {
        if (Build.VERSION.SDK_INT < 29) {
            throw FlutterError("UNSUPPORTED", "Biometric approvals need Android 10 or later")
        }
    }

    override fun isAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        val context = host.context ?: return false
        val bm = context.getSystemService(BiometricManager::class.java) ?: return false
        val result = if (Build.VERSION.SDK_INT >= 30) {
            bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            bm.canAuthenticate()
        }
        return result == BiometricManager.BIOMETRIC_SUCCESS
    }

    override suspend fun enroll(alias: String): DeviceKeyInfoMsg {
        requireSupported()
        if (!isAvailable()) throw FlutterError("NOT_ENROLLED", "No strong biometric is enrolled")
        return bg.run {
            AndroidKeys.generate(name(alias), challenge = null, preferStrongBox = false) {
                setUserAuthenticationRequired(true)
                setInvalidatedByBiometricEnrollment(true)
                if (Build.VERSION.SDK_INT >= 30) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                }
            }
            AndroidKeys.info(name(alias)) ?: throw FlutterError("FAILED", "Key generation failed")
        }
    }

    override fun keyState(alias: String): BiometricKeyStateMsg {
        if (!AndroidKeys.exists(name(alias))) return BiometricKeyStateMsg.MISSING
        return try {
            Signature.getInstance("SHA256withECDSA").initSign(AndroidKeys.privateKey(name(alias)))
            BiometricKeyStateMsg.VALID
        } catch (_: KeyPermanentlyInvalidatedException) {
            BiometricKeyStateMsg.INVALIDATED
        }
    }

    override suspend fun approve(alias: String, payload: ByteArray, title: String, reason: String): ByteArray {
        requireSupported()
        val activity = host.requireActivity()
        val signature = Signature.getInstance("SHA256withECDSA")
        try {
            signature.initSign(AndroidKeys.privateKey(name(alias)))
        } catch (_: KeyPermanentlyInvalidatedException) {
            throw FlutterError("ENROLLMENT_CHANGED", "Biometric enrollment changed since the key was created")
        }
        return suspendCancellableCoroutine { cont ->
            val cancel = CancellationSignal()
            cont.invokeOnCancellation { cancel.cancel() }
            val executor = activity.mainExecutor
            val builder = BiometricPrompt.Builder(activity)
                .setTitle(title)
                .setDescription(reason)
                .setNegativeButton(activity.getString(android.R.string.cancel), executor) { _, _ ->
                    if (cont.isActive) cont.resumeWithException(FlutterError("CANCELLED", "Cancelled"))
                }
            if (Build.VERSION.SDK_INT >= 30) {
                builder.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            }
            builder.build().authenticate(
                BiometricPrompt.CryptoObject(signature),
                cancel,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        if (!cont.isActive) return
                        try {
                            val s = result.cryptoObject?.signature
                                ?: throw FlutterError("FAILED", "No signature after authentication")
                            s.update(payload)
                            cont.resume(s.sign())
                        } catch (e: FlutterError) {
                            cont.resumeWithException(e)
                        } catch (e: Exception) {
                            cont.resumeWithException(FlutterError("FAILED", e.message))
                        }
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                        if (cont.isActive) {
                            cont.resumeWithException(FlutterError(errorCodeName(errorCode), errString?.toString()))
                        }
                    }
                },
            )
        }
    }

    override fun delete(alias: String) = AndroidKeys.delete(name(alias))

    companion object {
        fun errorCodeName(code: Int): String = when (code) {
            BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
            BiometricPrompt.BIOMETRIC_ERROR_CANCELED -> "CANCELLED"
            BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
            BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> "LOCKED_OUT"
            BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> "NOT_ENROLLED"
            BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
            BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "UNSUPPORTED"
            else -> "FAILED"
        }
    }
}
