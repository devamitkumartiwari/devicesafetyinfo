
package com.devamitkumartiwari.device_safety_info.vpn_check

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities


class VpnCheck{

    companion object{

        fun isActiveVPN(context: Context?): Boolean {
            var vpnInUse = false
            val connectivityManager: ConnectivityManager =
                context?.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork: Network? = connectivityManager.activeNetwork
            val caps: NetworkCapabilities? =
                connectivityManager.getNetworkCapabilities(activeNetwork)
            if (caps != null) {
                return caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            }
            val networks: Array<Network> = connectivityManager.allNetworks
            if (networks.isEmpty()){
                 vpnInUse = false;
            }else{
                for (i in networks.indices) {
                    val caps: NetworkCapabilities? = connectivityManager.getNetworkCapabilities(networks[i])
                    if (caps != null) {
                        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                            vpnInUse = true
                            break
                        }
                    }
                }
            }

            return vpnInUse
        }

    }

}