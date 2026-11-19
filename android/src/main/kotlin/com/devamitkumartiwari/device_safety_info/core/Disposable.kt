package com.devamitkumartiwari.device_safety_info.core

/** Implemented by anything holding listeners, views or threads that must be released when the
 *  plugin detaches from the engine. */
fun interface Disposable {
    fun dispose()
}
