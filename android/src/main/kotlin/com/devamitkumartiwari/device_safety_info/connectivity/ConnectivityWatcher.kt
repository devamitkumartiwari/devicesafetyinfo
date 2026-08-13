package com.devamitkumartiwari.device_safety_info.connectivity

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest

class ConnectivityWatcher {

    companion object {

        // Uses a broad (all-networks) request rather than registerDefaultNetworkCallback,
        // matching VpnCheck.isActiveVPN's own allNetworks scan: a VPN doesn't always become
        // the system's default route (split tunneling), and a default-only callback would
        // miss those connect/disconnect transitions.
        fun register(context: Context, onChanged: () -> Unit): ConnectivityManager.NetworkCallback {
            val connectivityManager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = onChanged()
                override fun onLost(network: Network) = onChanged()
                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: android.net.NetworkCapabilities
                ) = onChanged()
            }

            connectivityManager.registerNetworkCallback(NetworkRequest.Builder().build(), callback)
            return callback
        }

        fun unregister(context: Context, callback: ConnectivityManager.NetworkCallback) {
            try {
                val connectivityManager =
                    context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                connectivityManager.unregisterNetworkCallback(callback)
            } catch (_: Exception) {
                // Already unregistered, or engine detached mid-flight.
            }
        }
    }
}
