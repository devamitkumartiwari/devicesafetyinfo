package com.devamitkumartiwari.device_safety_info.integrity

import com.devamitkumartiwari.device_safety_info.core.Disposable
import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * `isPlayIntegrityAvailable`, `preparePlayIntegrity`, `requestPlayIntegrityToken` — client half of
 * Google Play Integrity (standard requests). The Play Integrity library is opt-in: when the
 * consuming app hasn't added `com.google.android.play:integrity`, every call except
 * `isPlayIntegrityAvailable` returns an `UNSUPPORTED` error instead of crashing.
 *
 * This class deliberately holds [PlayIntegrityClient] behind a nullable field created only after
 * the classpath check, so no Play Integrity type is resolved when the library is absent.
 */
class PlayIntegrityFeature(private val host: PluginHost) : FeatureMethodHandler, Disposable {

    override val methods = setOf(
        "isPlayIntegrityAvailable",
        "preparePlayIntegrity",
        "requestPlayIntegrityToken",
    )

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

    override fun handle(call: MethodCall, result: Result) {
        if (call.method == "isPlayIntegrityAvailable") {
            result.success(libraryPresent)
            return
        }
        if (!libraryPresent) {
            result.error(
                "UNSUPPORTED",
                "Play Integrity library not found. Add " +
                    "implementation(\"com.google.android.play:integrity:<version>\") to your app.",
                null,
            )
            return
        }
        val ctx = host.context ?: run {
            result.error("NO_CONTEXT", "Application context not attached", null)
            return
        }
        val c = client ?: PlayIntegrityClient(ctx).also { client = it }

        when (call.method) {
            "preparePlayIntegrity" -> {
                val number = call.argument<Number>("cloudProjectNumber")?.toLong() ?: run {
                    result.error("INVALID_INPUT", "cloudProjectNumber is required", null)
                    return
                }
                c.prepare(
                    number,
                    { result.success(null) },
                    { code, msg -> result.error(code, msg, null) },
                )
            }
            "requestPlayIntegrityToken" -> {
                val hash = call.argument<String>("requestHash") ?: run {
                    result.error("INVALID_INPUT", "requestHash is required", null)
                    return
                }
                c.request(
                    hash,
                    { token -> result.success(token) },
                    { code, msg -> result.error(code, msg, null) },
                )
            }
        }
    }

    override fun dispose() {
        client?.clear()
        client = null
    }
}
