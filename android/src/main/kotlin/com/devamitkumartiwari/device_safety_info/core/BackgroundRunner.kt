package com.devamitkumartiwari.device_safety_info.core

import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.withContext

/**
 * The one place blocking work runs: shell commands, file scans, PackageManager and Settings
 * queries. A small bounded pool shared by every feature, so a burst of checks can't spawn
 * unbounded threads and nothing blocking runs on the Android main thread.
 *
 * Pigeon's generated `suspend` handlers are launched on the main dispatcher; they call [run] to
 * hop here and resume on the main thread with the result. Any Throwable propagates to Pigeon,
 * which reports it to Dart as a PlatformException (the Dart check runner turns that into
 * `CheckStatus.error`), so a failing check can never crash the app.
 */
class BackgroundRunner(threads: Int = 3) {

    private val executor = Executors.newFixedThreadPool(threads, object : ThreadFactory {
        private val count = AtomicInteger()
        override fun newThread(r: Runnable): Thread =
            Thread(r, "device_safety_info-bg-${count.incrementAndGet()}").apply { isDaemon = true }
    })

    private val dispatcher: CoroutineDispatcher = executor.asCoroutineDispatcher()

    suspend fun <T> run(block: () -> T): T = withContext(dispatcher) { block() }

    fun shutdown() {
        executor.shutdown()
    }
}
