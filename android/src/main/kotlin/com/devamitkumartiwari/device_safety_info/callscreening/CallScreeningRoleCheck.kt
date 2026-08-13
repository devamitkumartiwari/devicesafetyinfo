package com.devamitkumartiwari.device_safety_info.callscreening

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build

// getRoleHolders()/getRoleHoldersAsUser() — the APIs that would answer "which package holds
// ROLE_CALL_SCREENING" — are @SystemApi behind android.permission.MANAGE_ROLE_HOLDERS, a
// signature|privileged permission Google Play does not grant third-party apps. There is no
// public API for a normal app to enumerate another app's role. The best a third-party app can do
// is check its own status and send the user to the OS role picker to review it themselves.
object CallScreeningRoleCheck {
    fun isRoleAvailable(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try {
            roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
        } catch (_: Exception) {
            false
        }
    }

    fun isRoleHeldByThisApp(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return try {
            roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        } catch (_: Exception) {
            false
        }
    }

    fun createRequestRoleIntent(context: Context): Intent? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val roleManager = context.getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return null
        return roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
    }
}
