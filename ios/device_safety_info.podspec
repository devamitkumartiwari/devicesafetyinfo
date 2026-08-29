#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint device_safety_info.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'device_safety_info'
  s.version          = '1.5.1'
  s.summary          = 'Flutter plugin for device security: root/jailbreak, emulator, VPN, hooking, screen capture, debugger detection.'
  s.description      = <<-DESC
A Flutter plugin providing security-focused device checks including jailbreak/root detection,
emulator detection, VPN detection, hooking framework detection (Frida/Xposed), screen capture
detection, developer mode detection, debugger detection, and store installation verification.
                       DESC
  s.homepage         = 'https://github.com/devamitkumartiwari/devicesafetyinfo'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Amit Kumar Tiwari' => 'amtechnovation@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'device_safety_info/Sources/device_safety_info/**/*', 'device_safety_info/Sources/device_safety_ffi/**/*'
  s.dependency 'Flutter'
  s.dependency 'IOSSecuritySuite', '~> 1.9'
  s.platform         = :ios, '16.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                       => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_ENABLE_MODULES'                 => 'YES',
    'OTHER_CFLAGS'                         => '-fvisibility=hidden'
  }
  s.swift_version = '5.9'
end
