package com.devamitkumartiwari.device_safety_info.rooted

/**
 * A utility to determine if the device is rooted.
 *
 * This object consolidates results from multiple checks to provide a comprehensive
 * assessment of the device's root status. It checks for:
 *  - The presence of common root-related files (`su` binaries).
 *  - The availability of root-related commands in the system PATH.
 *  - System properties that indicate a non-standard or test-keys build.
 */
object RootedDeviceCheck {

    /**
     * Checks if the device is rooted by combining multiple detection methods.
     *
     * @return `true` if any of the root indicators are found, `false` otherwise.
     */
    fun isRootedDevice(): Boolean {
        return RootFilesChecker.checkSuFiles() ||
                RootCommandsChecker.checkCommands() ||
                SystemPropsChecker.checkSystemProps()
    }
}
