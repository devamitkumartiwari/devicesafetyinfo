package com.devamitkumartiwari.device_safety_info.features.device_key

import com.devamitkumartiwari.device_safety_info.core.BackgroundRunner
import com.devamitkumartiwari.device_safety_info.generated.DeviceKeyHostApi
import com.devamitkumartiwari.device_safety_info.generated.DeviceKeyInfoMsg
import com.devamitkumartiwari.device_safety_info.generated.FlutterError
import java.security.Signature

/**
 * A device-bound signing key: generated in secure hardware, never exportable. With an
 * attestation challenge from your server, the certificate chain proves to that server that the
 * key lives in genuine hardware on a device with a verified boot state.
 */
class DeviceKeyHostApiImpl(private val bg: BackgroundRunner) : DeviceKeyHostApi {

    private fun name(alias: String) = AndroidKeys.alias("devicekey", alias)

    override suspend fun create(alias: String, challenge: ByteArray?, preferStrongBox: Boolean): DeviceKeyInfoMsg =
        bg.run {
            AndroidKeys.generate(name(alias), challenge, preferStrongBox)
            AndroidKeys.info(name(alias)) ?: throw FlutterError("FAILED", "Key generation failed")
        }

    override suspend fun info(alias: String): DeviceKeyInfoMsg? = bg.run { AndroidKeys.info(name(alias)) }

    override suspend fun sign(alias: String, data: ByteArray): ByteArray = bg.run {
        Signature.getInstance("SHA256withECDSA").run {
            initSign(AndroidKeys.privateKey(name(alias)))
            update(data)
            sign()
        }
    }

    override fun exists(alias: String): Boolean = AndroidKeys.exists(name(alias))

    override fun delete(alias: String) = AndroidKeys.delete(name(alias))
}
