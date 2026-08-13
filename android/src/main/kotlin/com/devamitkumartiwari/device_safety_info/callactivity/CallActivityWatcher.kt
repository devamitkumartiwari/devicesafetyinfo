package com.devamitkumartiwari.device_safety_info.callactivity

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.media.AudioRecordingConfiguration
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import java.util.concurrent.Executor

// Detects "is any call active" generically — native SIM calls via TelephonyManager, and VoIP
// calls from ANY app (WhatsApp/Teams/Skype/etc.) via system-wide audio routing state, which no
// app can avoid touching to actually carry a real-time voice/video call. This deliberately cannot
// identify which app is on a VoIP call — only that one is happening.
object CallActivityWatcher {

    enum class Source { SIM, VOIP }

    private fun hasSimCallSignal(context: Context): Boolean {
        val telephonyManager =
            context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return false
        return try {
            telephonyManager.callState != TelephonyManager.CALL_STATE_IDLE
        } catch (_: SecurityException) {
            // READ_PHONE_STATE not granted — degrade to VoIP-only signal.
            false
        }
    }

    private fun hasVoipAudioSignal(context: Context): Boolean {
        val audioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false

        if (audioManager.mode == AudioManager.MODE_IN_CALL ||
            audioManager.mode == AudioManager.MODE_IN_COMMUNICATION
        ) {
            return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            for (config in audioManager.activeRecordingConfigurations) {
                if (config.audioSource == MediaRecorder.AudioSource.VOICE_COMMUNICATION) return true
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            for (config in audioManager.activePlaybackConfigurations) {
                if (config.audioAttributes.usage == AudioAttributes.USAGE_VOICE_COMMUNICATION) return true
            }
        }

        return false
    }

    fun currentSource(context: Context): Source? {
        return when {
            hasSimCallSignal(context) -> Source.SIM
            hasVoipAudioSignal(context) -> Source.VOIP
            else -> null
        }
    }

    fun isCallActive(context: Context): Boolean = currentSource(context) != null

    // Cheap safety-net poll target — a single Binder getter, not the full config-list scan.
    fun currentAudioMode(context: Context): Int {
        val audioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                ?: return AudioManager.MODE_NORMAL
        return audioManager.mode
    }

    // --- Telephony push signal ---
    //
    // telephonyCallback is typed Any? (not TelephonyCallback?) to avoid referencing an API-31-only
    // class outside a version-guarded scope — same convention this file's sibling plugin file uses
    // for api34ScreenshotCallback, to avoid ART class-verification issues on older devices.
    class TelephonyHandle internal constructor(
        internal val telephonyManager: TelephonyManager,
        internal val telephonyCallback: Any?,
        internal val phoneStateListener: PhoneStateListener?,
    )

    fun registerTelephony(context: Context, mainHandler: Handler, onChange: () -> Unit): TelephonyHandle? {
        val telephonyManager =
            context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return null
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val callback = createTelephonyCallback(onChange)
                val executor = Executor { command -> mainHandler.post(command) }
                telephonyManager.registerTelephonyCallback(executor, callback)
                TelephonyHandle(telephonyManager, callback, null)
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java", ReplaceWith(""))
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        onChange()
                    }
                }
                @Suppress("DEPRECATION")
                telephonyManager.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                TelephonyHandle(telephonyManager, null, listener)
            }
        } catch (_: SecurityException) {
            // READ_PHONE_STATE not granted — caller degrades to VoIP-only signal.
            null
        }
    }

    @Suppress("NewApi")
    private fun createTelephonyCallback(onChange: () -> Unit): TelephonyCallback {
        return object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                onChange()
            }
        }
    }

    @Suppress("NewApi")
    fun unregisterTelephony(handle: TelephonyHandle?) {
        handle ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && handle.telephonyCallback != null) {
                handle.telephonyManager.unregisterTelephonyCallback(handle.telephonyCallback as TelephonyCallback)
            } else if (handle.phoneStateListener != null) {
                @Suppress("DEPRECATION")
                handle.telephonyManager.listen(handle.phoneStateListener, PhoneStateListener.LISTEN_NONE)
            }
        } catch (_: Exception) {}
    }

    // --- Audio push signal ---
    //
    // playbackCallback is typed Any? for the same API-gated-class-reference reason as above
    // (AudioManager.AudioPlaybackCallback is API 26+).
    class AudioCallbackHandle internal constructor(
        internal val audioManager: AudioManager,
        internal val recordingCallback: AudioManager.AudioRecordingCallback?,
        internal val playbackCallback: Any?,
    )

    fun registerAudioCallbacks(context: Context, mainHandler: Handler, onChange: () -> Unit): AudioCallbackHandle? {
        val audioManager =
            context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return null

        var recordingCallback: AudioManager.AudioRecordingCallback? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val cb = object : AudioManager.AudioRecordingCallback() {
                    override fun onRecordingConfigChanged(configs: MutableList<AudioRecordingConfiguration>?) {
                        onChange()
                    }
                }
                audioManager.registerAudioRecordingCallback(cb, mainHandler)
                recordingCallback = cb
            } catch (_: Exception) {}
        }

        var playbackCallback: Any? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                playbackCallback = createAudioPlaybackCallback(audioManager, mainHandler, onChange)
            } catch (_: Exception) {}
        }

        return AudioCallbackHandle(audioManager, recordingCallback, playbackCallback)
    }

    @Suppress("NewApi")
    private fun createAudioPlaybackCallback(
        audioManager: AudioManager,
        mainHandler: Handler,
        onChange: () -> Unit,
    ): AudioManager.AudioPlaybackCallback {
        val callback = object : AudioManager.AudioPlaybackCallback() {
            override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>?) {
                onChange()
            }
        }
        audioManager.registerAudioPlaybackCallback(callback, mainHandler)
        return callback
    }

    @Suppress("NewApi")
    fun unregisterAudioCallbacks(handle: AudioCallbackHandle?) {
        handle ?: return
        try {
            handle.recordingCallback?.let { handle.audioManager.unregisterAudioRecordingCallback(it) }
        } catch (_: Exception) {}
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && handle.playbackCallback != null) {
                handle.audioManager.unregisterAudioPlaybackCallback(handle.playbackCallback as AudioManager.AudioPlaybackCallback)
            }
        } catch (_: Exception) {}
    }
}
