import Foundation
import UIKit

class StoreInstallCheck {

    static let trustedStores = ["com.apple.AppStore", "com.apple.TestFlight"]

    static func isBinaryEncrypted() -> Bool {
        guard let execPath = Bundle.main.executablePath,
              let fileData = try? Data(contentsOf: URL(fileURLWithPath: execPath)) else {
            return false
        }

        let binaryBase = (fileData as NSData).bytes.bindMemory(to: UInt8.self, capacity: fileData.count)
        var machHeader = binaryBase.bindMemory(to: mach_header.self, capacity: 1).pointee

        // Handle fat binary
        if machHeader.magic == FAT_CIGAM {
            let fatHeader = binaryBase.bindMemory(to: fat_header.self, capacity: 1).pointee
            var fatArch = binaryBase.advanced(by: MemoryLayout<fat_header>.size).bindMemory(to: fat_arch.self, capacity: 1)

            for _ in 0..<Int(fatHeader.nfat_arch.bigEndian) {
                if (MemoryLayout<Int>.size == 4 && fatArch.pointee.cputype.bigEndian & CPU_ARCH_ABI64 == 0) ||
                   (MemoryLayout<Int>.size == 8 && fatArch.pointee.cputype.bigEndian & CPU_ARCH_ABI64 != 0) {
                    let offset = fatArch.pointee.offset.bigEndian
                    machHeader = binaryBase.advanced(by: Int(offset)).bindMemory(to: mach_header.self, capacity: 1).pointee
                    break
                }
                fatArch = fatArch.advanced(by: 1)
            }
        }

        // Determine 32-bit or 64-bit Mach-O header
        var loadCommand: UnsafePointer<load_command>
        if machHeader.magic == MH_MAGIC {
            loadCommand = binaryBase.advanced(by: MemoryLayout<mach_header>.size).bindMemory(to: load_command.self, capacity: 1)
        } else if machHeader.magic == MH_MAGIC_64 {
            loadCommand = binaryBase.advanced(by: MemoryLayout<mach_header_64>.size).bindMemory(to: load_command.self, capacity: 1)
        } else {
            return false
        }

        // Iterate over load commands
        for _ in 0..<machHeader.ncmds {
            switch loadCommand.pointee.cmd {
            case UInt32(LC_ENCRYPTION_INFO):
                let cryptCmd = loadCommand.withMemoryRebound(to: encryption_info_command.self, capacity: 1) { $0.pointee }
                if cryptCmd.cryptid != 0 {
                    return true
                }

            case UInt32(LC_ENCRYPTION_INFO_64):
                let cryptCmd64 = loadCommand.withMemoryRebound(to: encryption_info_command_64.self, capacity: 1) { $0.pointee }
                if cryptCmd64.cryptid != 0 {
                    return true
                }

            default:
                break
            }

            loadCommand = loadCommand.advanced(by: Int(loadCommand.pointee.cmdsize) / MemoryLayout<load_command>.size)
        }

        return false
    }

    static func isInstalledFromStore() -> Bool {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }

        let path = appStoreReceiptURL.path

        // Check if the receipt path matches the trusted stores (App Store or TestFlight)
        if path.contains("sandboxReceipt") {
            // TestFlight installation
            return trustedStores.contains("com.apple.TestFlight")
        } else if path.contains("receipt") {
            // App Store installation
            return trustedStores.contains("com.apple.AppStore")
        }

        return false
    }

    // Combined check: both installation source and binary encryption
    static func isValidApp() -> Bool {
        return isInstalledFromStore() && isBinaryEncrypted()
    }
}
