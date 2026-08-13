package com.devamitkumartiwari.device_safety_info.sideload

import android.content.Context
import android.os.Build
import android.provider.Settings

// SCOPE NOTE: on API 26+, canRequestPackageInstalls() is a PER-CALLING-APP grant
// (REQUEST_INSTALL_PACKAGES + a user toggle at Settings > Apps > <this app> > Install unknown
// apps). It answers "can *this app* sideload" — it structurally cannot answer "has some other
// (attacker) app been granted install rights", since that grant isn't readable across app
// boundaries without a privileged permission. Only on API 24-25 does the old device-wide toggle
// genuinely answer the device-wide question.
object UnknownSourcesCheck {
    fun isUnknownSourcesEnabled(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                context.packageManager.canRequestPackageInstalls()
            } catch (e: SecurityException) {
                false
            }
        } else {
            @Suppress("DEPRECATION")
            Settings.Secure.getInt(context.contentResolver, Settings.Secure.INSTALL_NON_MARKET_APPS, 0) == 1
        }
    }
}
