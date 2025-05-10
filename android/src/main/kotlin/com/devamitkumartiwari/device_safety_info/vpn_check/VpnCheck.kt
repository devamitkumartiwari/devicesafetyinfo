package com.devamitkumartiwari.device_safety_info.vpn_check

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities

class VpnCheck {

    companion object {

        fun isActiveVPN(context: Context?): Boolean {
            context ?: return false // Return false if context is null

            val connectivityManager: ConnectivityManager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

            // Check if VPN is active on the current active network
            val activeNetwork: Network? = connectivityManager.activeNetwork
            val networkCapabilities: NetworkCapabilities? =
                connectivityManager.getNetworkCapabilities(activeNetwork)

            if (networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                return true
            }

            // Check all networks to see if any are VPNs
            val networks: Array<Network> = connectivityManager.allNetworks
            for (network in networks) {
                val capabilities: NetworkCapabilities? =
                    connectivityManager.getNetworkCapabilities(network)
                if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                    return true
                }
            }

            return false
        }
    }
}
