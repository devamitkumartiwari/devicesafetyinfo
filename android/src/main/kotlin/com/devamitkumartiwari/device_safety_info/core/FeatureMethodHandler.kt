package com.devamitkumartiwari.device_safety_info.core

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * One vertical feature slice's handling of a subset of `MethodChannel` calls. Each concrete
 * feature declares the method names it owns via [methods]; [DeviceSafetyInfoPlugin] builds a flat
 * `methodName -> handler` map from every registered feature's [methods] once, in
 * `onAttachedToEngine`, and dispatches by lookup instead of one large `when` block.
 */
interface FeatureMethodHandler {
    val methods: Set<String>
    fun handle(call: MethodCall, result: MethodChannel.Result)
}

/**
 * Implemented by any feature that owns resources needing explicit teardown (background executors,
 * registered listeners/observers, cached state, overlay views). [DeviceSafetyInfoPlugin] calls
 * [dispose] on every disposable feature from `onDetachedFromEngine`, preserving every cleanup step
 * that previously lived inline there.
 */
interface Disposable {
    fun dispose()
}
