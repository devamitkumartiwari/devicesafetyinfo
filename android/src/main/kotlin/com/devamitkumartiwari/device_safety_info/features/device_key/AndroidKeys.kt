package com.devamitkumartiwari.device_safety_info.features.device_key

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.Base64
import com.devamitkumartiwari.device_safety_info.generated.DeviceKeyInfoMsg
import com.devamitkumartiwari.device_safety_info.generated.FlutterError
import com.devamitkumartiwari.device_safety_info.generated.KeySecurityLevelMsg
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.ECGenParameterSpec

/**
 * EC P-256 signing keys in the Android Keystore. Private keys never leave secure hardware
 * (StrongBox when available and requested, otherwise the TEE; software only on devices without
 * either, which [DeviceKeyInfoMsg.securityLevel] reports).
 */
internal object AndroidKeys {
    private const val PROVIDER = "AndroidKeyStore"

    /** Plugin namespace, so app aliases can't collide with other Keystore users. */
    fun alias(kind: String, alias: String) = "dsi.$kind.$alias"

    private fun store(): KeyStore = KeyStore.getInstance(PROVIDER).apply { load(null) }

    fun exists(name: String): Boolean = store().containsAlias(name)

    fun delete(name: String) {
        val ks = store()
        if (ks.containsAlias(name)) ks.deleteEntry(name)
    }

    fun privateKey(name: String): PrivateKey =
        store().getKey(name, null) as? PrivateKey
            ?: throw FlutterError("KEY_MISSING", "No key named $name")

    /**
     * Generates a key. [configure] adds purpose-specific options (e.g. user authentication).
     * With [preferStrongBox], StrongBox is tried first and the TEE used if it's unavailable.
     */
    fun generate(
        name: String,
        challenge: ByteArray?,
        preferStrongBox: Boolean,
        configure: KeyGenParameterSpec.Builder.() -> Unit = {},
    ) {
        fun spec(strongBox: Boolean): KeyGenParameterSpec {
            val b = KeyGenParameterSpec.Builder(name, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
            if (challenge != null) b.setAttestationChallenge(challenge)
            if (strongBox && Build.VERSION.SDK_INT >= 28) b.setIsStrongBoxBacked(true)
            b.configure()
            return b.build()
        }

        fun run(strongBox: Boolean) {
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, PROVIDER).apply {
                initialize(spec(strongBox))
                generateKeyPair()
            }
        }

        delete(name)
        if (preferStrongBox && Build.VERSION.SDK_INT >= 28) {
            try {
                run(strongBox = true)
                return
            } catch (_: StrongBoxUnavailableException) {
                // Fall back to the TEE below.
            }
        }
        run(strongBox = false)
    }

    fun info(name: String): DeviceKeyInfoMsg? {
        val ks = store()
        if (!ks.containsAlias(name)) return null
        val chain = ks.getCertificateChain(name).orEmpty()
        val leaf = chain.firstOrNull() ?: ks.getCertificate(name)
            ?: throw FlutterError("FAILED", "Key $name has no certificate")
        return DeviceKeyInfoMsg(
            publicKey = b64(leaf.publicKey.encoded),
            securityLevel = securityLevel(privateKey(name)),
            // A chain of one is the Keystore's self-signed placeholder, not an attestation.
            attestationChain = if (chain.size > 1) chain.map { b64(it.encoded) } else emptyList(),
        )
    }

    private fun securityLevel(key: PrivateKey): KeySecurityLevelMsg = try {
        val info = KeyFactory.getInstance(key.algorithm, PROVIDER).getKeySpec(key, KeyInfo::class.java)
        if (Build.VERSION.SDK_INT >= 31) {
            when (info.securityLevel) {
                KeyProperties.SECURITY_LEVEL_STRONGBOX -> KeySecurityLevelMsg.STRONG_BOX
                KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> KeySecurityLevelMsg.TEE
                else -> KeySecurityLevelMsg.SOFTWARE
            }
        } else {
            @Suppress("DEPRECATION")
            if (info.isInsideSecureHardware) KeySecurityLevelMsg.TEE else KeySecurityLevelMsg.SOFTWARE
        }
    } catch (_: Exception) {
        KeySecurityLevelMsg.SOFTWARE
    }

    private fun b64(bytes: ByteArray): String = Base64.encodeToString(bytes, Base64.NO_WRAP)
}
