package com.devamitkumartiwari.device_safety_info.versioncheck

import com.devamitkumartiwari.device_safety_info.core.FeatureMethodHandler
import com.devamitkumartiwari.device_safety_info.core.PluginHost
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/** `getPackageInfo` method — this app's own package name + version, for the Dart-side new-version
 * check feature. */
class VersionCheckFeature(private val host: PluginHost) : FeatureMethodHandler {

    override val methods = setOf("getPackageInfo")

    override fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "getPackageInfo" -> {
                val ctx = host.context ?: run {
                    result.error("NO_CONTEXT", "Application context not attached", null)
                    return
                }
                try {
                    val pInfo = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
                    result.success(mapOf(
                        "packageName" to ctx.packageName,
                        "version" to (pInfo.versionName ?: "0.0.0")
                    ))
                } catch (e: Exception) {
                    result.error("PACKAGE_INFO_ERROR", e.message, null)
                }
            }
        }
    }
}
