package com.example.device_safety_info.rooted

import android.content.Context
import android.os.Build
import java.util.*
import com.scottyab.rootbeer.RootBeer


class RootedDeviceCheck {

    companion object{

        private val ONEPLUS = "oneplus"
        private val MOTO = "moto"
        private val XIAOMI = "xiaomi"
        private val LENOVO = "lenovo"

        fun isRootedDevice(context: Context): Boolean {
            val check: CheckApiVersion = if (Build.VERSION.SDK_INT >= 23) {
                GreaterThan23()
            } else {
                LessThan23()
            }
            return check.checkRootedDevice() || rootBeerCheck(context)
        }

        private fun rootBeerCheck(context: Context): Boolean {
            val rootBeer = RootBeer(context)
            val brand = Build.BRAND.lowercase(Locale.getDefault())
            return if (brand.contains(ONEPLUS) || brand.contains(MOTO) || brand.contains(XIAOMI) || brand.contains(
                    LENOVO
                )
            ) {
                rootBeer.isRootedWithBusyBoxCheck
//            rootBeer.isRootedWithoutBusyBoxCheck
            } else {
                rootBeer.isRooted
            }
        }

    }



}